final Set<String> _authRequiredTickets = <String>{};

String buildAuthRequiredLocation({required String from}) {
  final ticket = DateTime.now().microsecondsSinceEpoch.toString();
  _authRequiredTickets.add(ticket);
  return Uri(
    path: '/auth-required',
    queryParameters: {
      'from': from,
      'ticket': ticket,
    },
  ).toString();
}

bool isValidAuthRequiredTicket(String? ticket) {
  if (ticket == null || ticket.isEmpty) {
    return false;
  }
  return _authRequiredTickets.remove(ticket);
}
