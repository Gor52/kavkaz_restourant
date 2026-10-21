from locust import HttpUser, TaskSet, SequentialTaskSet, task, between
from faker import Faker
import random

fake = Faker('ru_RU')

class GuestTasks(TaskSet):

    @task(5)
    def view_categories(self):
        self.client.get("/menu/categories", name="/menu/categories")

    @task(10)
    def view_dishes(self):
        self.client.get("/menu/dishes", name="/menu/dishes")

    @task(3)
    def view_single_dish(self):
        dish_id = random.choice([11, 12, 10, 9])
        self.client.get(f"/menu/dishes/{dish_id}", name="/menu/dishes/[id]")
        
    @task(2)
    def view_reviews(self):
        dish_id = random.choice([11, 12, 10, 9])
        self.client.get(f"/reviews?dish_id={dish_id}", name="/reviews")


class AuthClientTasks(SequentialTaskSet):

    def on_start(self):
        self.password = "Password123!" 
        self.email = fake.unique.email()
        self.phone = fake.unique.phone_number()[:15]
        
        self.client.post("/auth/register", json={
            "full_name": fake.name(),
            "phone": self.phone,
            "email": self.email,
            "password": self.password
        }, name="/auth/register")
        
        login_resp = self.client.post("/auth/login", json={
            "login": self.email,
            "password": self.password
        }, name="/auth/login")
        
        if login_resp.status_code == 200:
            token = login_resp.json().get("access_token")
            self.client.headers.update({"Authorization": f"Bearer {token}"})

    @task
    def view_profile(self):
        self.client.get("/profile", name="/profile")

    @task
    def add_address(self):
        with self.client.post("/profile/addresses", json={
            "address_text": fake.address(),
            "comment": "Домофон не работает"
        }, name="/profile/addresses", catch_response=True) as resp:
            if resp.status_code == 201:
                self.address_id = resp.json().get("id_address")
            else:
                resp.success() 

    @task
    def add_to_cart(self):
        self.client.post("/cart/items", json={
            "dish_id": random.choice([11, 12, 10, 9]),
            "quantity": random.randint(1, 3)
        }, name="/cart/items")

    @task
    def make_order(self):
        if hasattr(self, 'address_id'):
            self.client.post("/orders", json={
                "pickup_type_id": 1,
                "payment_method_id": 1, 
                "address_id": self.address_id,
                "receive_time": fake.future_datetime(end_date="+1d").isoformat()
            }, name="/orders")

    @task
    def make_booking(self):
        self.client.post("/bookings", json={
            "booking_date": fake.future_date(end_date="+14d").isoformat(),
            "booking_time": f"{random.randint(10, 22)}:00",
            "guest_count": random.randint(1, 6),
            "comment": "Столик у окна"
        }, name="/bookings")


class AppUser(HttpUser):
    wait_time = between(1, 3)

    tasks = {
        GuestTasks: 6, 
        AuthClientTasks: 1
    }