import 'package:flutter/material.dart';

class NavigationModel {
  String name;
  String activeIcon;
  String inactiveIcon;
  Widget screen;
  /// Show the unread notifications count on this tab.
  bool unreadBadge;

  NavigationModel({required this.name, required this.activeIcon, required this.inactiveIcon, required this.screen, this.unreadBadge = false});
}