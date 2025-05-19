import 'package:flutter/material.dart';
import 'package:chit_fund_flutter/models/member.dart';

// Placeholder for MemberDetails until we implement it
class MemberDetails extends StatelessWidget {
  final Member member;
  final Function? onUpdate;

  const MemberDetails({
    Key? key,
    required this.member,
    this.onUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(member.name),
      ),
      body: Center(
        child: Text('Member details will be implemented here'),
      ),
    );
  }
}
