import 'package:flutter/material.dart';
import 'package:chit_fund_flutter/screens/splash_screen_new.dart';
import 'package:chit_fund_flutter/screens/login/login_screen.dart';
import 'package:chit_fund_flutter/screens/login/register_screen.dart';
import 'package:chit_fund_flutter/screens/dashboard/dashboard_screen.dart';
import 'package:chit_fund_flutter/screens/members/members_screen.dart';
import 'package:chit_fund_flutter/screens/members/member_form.dart';
import 'package:chit_fund_flutter/screens/groups/groups_screen.dart';
import 'package:chit_fund_flutter/screens/loans/loans_screen.dart';
import 'package:chit_fund_flutter/screens/loans/loan_form.dart';
import 'package:chit_fund_flutter/screens/chit_funds/chit_funds_screen.dart';
import 'package:chit_fund_flutter/models/member.dart';
import 'package:chit_fund_flutter/services/database_service.dart';
import 'package:chit_fund_flutter/screens/chit_funds/chit_fund_form.dart';
import 'package:chit_fund_flutter/screens/members/member_details.dart';
import 'package:chit_fund_flutter/screens/payments/pending_emis_screen.dart';
import 'package:chit_fund_flutter/screens/utils/database_reset_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String members = '/members';
  static const String addMember = '/members/add';
  static const String groups = '/groups';
  static const String loans = '/loans';
  static const String addLoan = '/loans/add';
  static const String chitFunds = '/chit-funds';
  static const String addChitFund = '/chit-funds/add';
  static const String pendingEMIs = '/emi/pending';
  static const String memberDetails = '/members/details';
  static const String databaseReset = '/utils/database-reset';
  
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      splash: (context) => const SplashScreen(),
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      dashboard: (context) => const DashboardScreen(),
      members: (context) => const MembersScreen(),
      addMember: (context) => MemberForm(
        onSuccess: () {
          Navigator.popAndPushNamed(context, members);
        },
      ),
      groups: (context) => const GroupsScreen(),
      loans: (context) => const LoansScreen(),
      addLoan: (context) => LoanForm(
        onSuccess: () {
          Navigator.popAndPushNamed(context, loans);
        },
      ),
      chitFunds: (context) => const ChitFundsScreen(),
      addChitFund: (context) => ChitFundForm(
        onSuccess: () {
          Navigator.popAndPushNamed(context, chitFunds);
        },
      ),
      pendingEMIs: (context) => const PendingEMIsScreen(),
      databaseReset: (context) => const DatabaseResetScreen(),
      memberDetails: (context) {
        final aadhaar = ModalRoute.of(context)!.settings.arguments as String;
        return FutureBuilder<Member?>(
          future: DatabaseService().getMember(aadhaar),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: Center(child: Text('Error loading member: ${snapshot.error}')),
              );
            } else if (!snapshot.hasData || snapshot.data == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Member Not Found')),
                body: const Center(child: Text('Member not found.')),
              );
            } else {
              return MemberDetails(member: snapshot.data!);
            }
          },
        );
      },
    };
  }
}
