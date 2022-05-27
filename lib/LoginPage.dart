import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:capacity_access_employee/PanelPage.dart';
import 'package:capacity_access_employee/RegisterPage.dart';
import 'package:capacity_access_employee/main.dart';
import 'package:capacity_access_employee/themes/theme_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:preferences/preference_service.dart';
import 'package:provider/provider.dart';
import 'package:typed_data/typed_data.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPage createState() => _LoginPage();
}

class _LoginPage extends State<LoginPage> {
  TextEditingController userController = new TextEditingController();
  TextEditingController pwdController = new TextEditingController();
  TextEditingController brokerController = new TextEditingController();

  late MqttClient subclient;

  String topic_pub = "loginEmpleado";

  String topic_sub = "receiveLoginEmpleado";

  String sender = "";

  @override
  void initState() {
    super.initState();
    String broker = PrefService.getString("broker") ?? "";
    String user = PrefService.getString("user") ?? "";
    String pwd = PrefService.getString("pwd") ?? "";
    if (broker != "") {
      brokerController.text = broker;
    }

    if (user != "") {
      userController.text = user;
    }

    if (pwd != "") {
      pwdController.text = pwd;
    }
    var rng = Random();
  }

  void dispose() {
    super.dispose();
    subclient.unsubscribe(topic_sub);
    subclient.disconnect();
  }

  void getToken() async {
    var deviceState = await OneSignal.shared.getDeviceState();
    String tokenSend = deviceState!.userId.toString();
    PrefService.setString('tokenOneSignal', tokenSend);
  }

  bool compruebaIp(String ip) {
    try {
      final list1 = ip.split(".");

      if (list1.length == 4) {
        for (String byte in list1) {
          int nbyte = int.parse(byte);
          if (nbyte > 255 || nbyte < 0) {
            return false;
          }
        }

        return true;
      } else {
        return false;
      }
    } catch (Exception) {
      return false;
    }
  }

  Future<int> pub(String topic, String message) async {
    var rng = Random();

    String mqttBroker = PrefService.getString("broker");
    final MqttClient client =
        MqttServerClient(mqttBroker, 'flutter' + rng.nextInt(100).toString());

    client.logging(on: false);
    client.keepAlivePeriod = 2;

    final MqttConnectMessage connMess = MqttConnectMessage()
        .withClientIdentifier(message)
        .keepAliveFor(2)
        .startClean();

    client.connectionMessage = connMess;

    try {
      await client.connect();
    } on Exception catch (e) {
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      String pubTopic = topic;
      final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
      builder.addString(message);
      Uint8Buffer? send = builder.payload;
      client.publishMessage(pubTopic, MqttQos.exactlyOnce, send!);
    } else {
      client.disconnect();
    }

    await MqttUtilities.asyncSleep(10);

    return 0;
  }

  Future<int> sub(MqttClient client, String topic) async {
    client.logging(on: false);
    client.keepAlivePeriod = 2;

    final MqttConnectMessage connMess = MqttConnectMessage()
        .withClientIdentifier("sub" + topic.toString())
        .keepAliveFor(2)
        .startClean();

    client.connectionMessage = connMess;

    try {
      await client.connect();
    } on Exception catch (e) {
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      String topic_a = topic;
      client.subscribe(topic_a, MqttQos.atMostOnce);
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        String newJson = '';
        newJson = pt.replaceAll("'", "\"");
        Map<String, dynamic> json2 = jsonDecode(newJson);

        String receiver = json2['receiver'].toString();
        if (receiver == sender) {
          PrefService.setString('message', pt);
          PrefService.setString('receive', 'true');
          PrefService.setString('lock', 'false');
        }
      });
    } else {
      client.disconnect();
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Consumer<ThemeModel>(
        builder: (context, ThemeModel themeNotifier, child) {
      themeNotifier.isDark = false;

      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [],
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Container(
            width: size.width,
            height: size.height,
            padding: EdgeInsets.only(
                left: 20, right: 20, bottom: size.height * 0.2, top: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 40),
                        Image(
                            width: 190,
                            alignment: Alignment.center,
                            image: AssetImage('assets/images/LOGO.png')),
                        SizedBox(width: 40),
                      ],
                    ),
                    SizedBox(
                      height: 50,
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      decoration: BoxDecoration(
                          color: Theme.of(context).primaryColorLight,
                          borderRadius: BorderRadius.all(Radius.circular(20))),
                      child: TextField(
                        controller: userController,
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Nickname (max. 10 carácteres)"),
                      ),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      decoration: BoxDecoration(
                          color: Theme.of(context).primaryColorLight,
                          borderRadius: BorderRadius.all(Radius.circular(20))),
                      child: TextField(
                        controller: pwdController,
                        obscureText: true,
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Contraseña (max. 20 carácteres)"),
                      ),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                      decoration: BoxDecoration(
                          color: Theme.of(context).primaryColorLight,
                          borderRadius: BorderRadius.all(Radius.circular(20))),
                      child: TextField(
                        controller: brokerController,
                        obscureText: false,
                        decoration: InputDecoration(
                            border: InputBorder.none, hintText: "Broker"),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    RaisedButton(
                      key: Key("loginButton"),
                      onPressed: () {
                        var rng = Random();
                        if (brokerController.text.isNotEmpty &&
                            userController.text.isNotEmpty &&
                            pwdController.text.isNotEmpty) {
                          if (userController.text.length <= 10 &&
                              pwdController.text.length <= 20) {
                            showToast("Espere un momento...");
                            PrefService.setString("user", userController.text);
                            PrefService.setString("pwd", pwdController.text);
                            getToken();
                            if (compruebaIp(brokerController.text)) {
                              PrefService.setString(
                                  "broker", brokerController.text);
                              subclient = MqttServerClient(
                                  brokerController.text,
                                  'flutter' + rng.nextInt(100).toString());

                              sub(subclient, topic_sub).then((value) {
                                PrefService.setString("lock", "true");
                                PrefService.setString("receive", "false");
                                PrefService.setString('message', '');
                                String nick = userController.text;
                                String pwd = pwdController.text;
                                var rgn = Random();
                                sender = nick;
                                String sendable =
                                    "{\"function\" : \"loginEmpleado\", \"sender\" : \"$sender\", \"data\" : {\"nick\" : \"$nick\", \"pwd\" : \"$pwd\"}}";
                                pub(topic_pub, sendable);

                                String n = PrefService.getString("lock");
                                int p = 0;
                                Future.doWhile(() async {
                                  await Future.delayed(
                                      Duration(milliseconds: 500));

                                  bool ok = true;
                                  String n = PrefService.getString("lock");

                                  if (n != "true" || p == 20) {
                                    PrefService.setString("lock", "true");
                                    ok = false;
                                  }
                                  p++;

                                  return ok;
                                }).then((value) {
                                  sleep(Duration(milliseconds: 500));

                                  String p = PrefService.getString("receive");

                                  if (p == "true") {
                                    String msg =
                                        PrefService.getString('message');
                                    PrefService.setString("receive", "false");
                                    String newJson = '';
                                    newJson = msg.replaceAll("'", "\"");
                                    Map<String, dynamic> json2 =
                                        jsonDecode(newJson);
                                    String function =
                                        json2['function'].toString();

                                    if (function == "loginEmpleado") {
                                      String status =
                                          json2['status'].toString();

                                      if (status == "OK") {
                                        showToast("Acceso concedido");
                                        String aforo_actual = json2['data']
                                                ['aforo_actual']
                                            .toString();
                                        String aforo_max = json2['data']
                                                ['aforo_max']
                                            .toString();

                                        int actual = int.parse(aforo_actual);
                                        int max = int.parse(aforo_max);
                                        PrefService.setString("sender", nick);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  PanelPage(actual, max)),
                                        );
                                      } else {
                                        showToast(json2['message'].toString());
                                      }
                                    } else {
                                      showToast("Error en el proceso");
                                    }
                                  } else {
                                    showToast(
                                        "Error de comunicación por tópico");
                                  }
                                  PrefService.setString('message', '');
                                });
                              });
                            } else {
                              showToast("Dirección IP del broker inválida");
                            }
                          } else {
                            showToast("Exceso en el límite de carácteres");
                          }
                        } else {
                          showToast("Te faltan datos por rellenar");
                        }
                      },
                      elevation: 0,
                      padding: EdgeInsets.all(18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Center(
                          child: Text(
                        "Login",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      )),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    RaisedButton(
                      key: Key("registerButton"),
                      onPressed: () {
                        if (brokerController.text.isNotEmpty) {
                          if (compruebaIp(brokerController.text)) {
                            getToken();
                            PrefService.setString(
                                "broker", brokerController.text);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => RegisterPage()),
                            );
                          } else {
                            showToast("Dirección IP del broker inválida");
                          }
                        } else {
                          showToast("Debes indicar un broker");
                        }
                      },
                      elevation: 0,
                      padding: EdgeInsets.all(18),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Center(
                          child: Text(
                        "Crear una cuenta",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      )),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      );
    });
  }
}
