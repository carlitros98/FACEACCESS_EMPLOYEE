import 'dart:io';

import 'package:capacity_access_employee/LoginPage.dart';

import 'package:capacity_access_employee/themes/app_theme.dart';
import 'package:capacity_access_employee/themes/theme_model.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:preferences/preferences.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrefService.init(prefix: 'pref_');
  OneSignal.shared.setAppId("b150d07e-3f0a-42bb-a7ee-6d9c5d2650e2");
  runApp(ChangeNotifierProvider(
      create: (_) => ThemeModel(),
      child: Consumer<ThemeModel>(
          builder: (context, ThemeModel themeNotifier, child) {
        return MaterialApp(
          home: LoginPage(),
          theme: themeNotifier.isDark ? AppTheme.dark : AppTheme.light,
          debugShowCheckedModeBanner: false,
        );
      })));
}

void showToast(String mensaje) {
  Fluttertoast.showToast(
      msg: mensaje,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIos: 2,
      backgroundColor: Colors.black,
      textColor: Colors.white);
}
