import 'package:flutter/material.dart';
import 'package:resq_frontend/pages/user/user_service.dart';
import 'package:resq_frontend/routes.dart';

class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  bool _navigated = false;
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    try {
      final me = await UserService.fetchMe();
      if (!mounted) return;
      if (_navigated) return;
      _navigated = true;
      if (me == null) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      final role = me.role.toString().toUpperCase();
      if (role == 'ADMIN') {
        Navigator.pushReplacementNamed(context, AppRoutes.shelterAdmin);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.map);
      }
    } catch (_) {
      if (!mounted) return;
      if (_navigated) return;
      _navigated = true;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
