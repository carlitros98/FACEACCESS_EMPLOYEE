import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:capacity_access_employee/PanelPage.dart';
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

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPage createState() => _RegisterPage();
}

class _RegisterPage extends State<RegisterPage> {
  TextEditingController nameController = new TextEditingController();
  TextEditingController surnameController = new TextEditingController();

  TextEditingController userController = new TextEditingController();
  TextEditingController pwdController = new TextEditingController();

  TextEditingController licController = new TextEditingController();

  late MqttClient subclient;

  String topic_pub = "altaEmpleado";

  String topic_sub = "receiveAltaEmpleado";

  String sender = "";

  @override
  void initState() {
    super.initState();
    var rng = Random();
    String mqttBroker = PrefService.getString("broker");
    subclient =
        MqttServerClient(mqttBroker, 'flutter' + rng.nextInt(100).toString());

    sub(subclient, topic_sub);
  }

  void dispose() {
    super.dispose();
    subclient.unsubscribe(topic_sub);
    subclient.disconnect();
  }

  Future<int> pub(String topic, String message) async {
    var rng = Random();

    String mqttBroker = PrefService.getString("broker");
    print("pub 9" + mqttBroker);

    final MqttClient client =
        MqttServerClient(mqttBroker, 'flutter' + rng.nextInt(100).toString());
    print("pub 9");

    client.logging(on: false);
    client.keepAlivePeriod = 2;

    final MqttConnectMessage connMess = MqttConnectMessage()
        .withClientIdentifier(message)
        .keepAliveFor(2)
        .startClean();

    client.connectionMessage = connMess;
    print("pub 9");

    try {
      await client.connect();
      print("pub 9");
    } on Exception catch (e) {
      print("ERRNO: " + e.toString());
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      String pubTopic = topic;
      final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
      builder.addString(message);
      Uint8Buffer? send = builder.payload;
      print("pub 9");

      client.publishMessage(pubTopic, MqttQos.exactlyOnce, send!);
      print("pub 9");
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
        try {
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
        } on Exception {}
      });
    } else {
      client.disconnect();
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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
                        controller: nameController,
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Nombre (max. 20 carácteres)"),
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
                        controller: surnameController,
                        obscureText: false,
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Apellidos (max. 50 carácteres)"),
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
                        controller: userController,
                        obscureText: false,
                        decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Nombre usuario (max. 10 carácteres)"),
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
                        controller: licController,
                        obscureText: false,
                        decoration: InputDecoration(
                            border: InputBorder.none, hintText: "Nº licencia"),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    RaisedButton(
                      onPressed: () {
                        if (userController.text.isNotEmpty &&
                            pwdController.text.isNotEmpty &&
                            licController.text.isNotEmpty &&
                            nameController.text.isNotEmpty &&
                            surnameController.text.isNotEmpty) {
                          if (userController.text.length <= 10 &&
                              pwdController.text.length <= 20 &&
                              nameController.text.length <= 20 &&
                              surnameController.text.length <= 50) {
                            PrefService.setString("user", userController.text);
                            PrefService.setString("pwd", pwdController.text);

                            PrefService.setString("lock", "true");
                            PrefService.setString("receive", "false");
                            PrefService.setString('message', '');
                            String nick = userController.text;
                            String name = nameController.text;
                            String pwd = pwdController.text;
                            String surname = surnameController.text;
                            String certificado = licController.text;
                            var rgn = Random();
                            String onesignal =
                                PrefService.getString('tokenOneSignal');
                            sender = nick;

                            String sendable =
                                "{\"function\" : \"altaEmpleado\", \"sender\" : \"$sender\", \"data\" : " +
                                    "{\"nick\" : \"$nick\", \"name\" : \"$name\", \"pwd\" : \"$pwd\", \"surname\" : \"$surname\"," +
                                    " \"id_cert\" : \"$certificado\", \"id_onesignal\" : \"$onesignal\"}}";

                            pub(topic_pub, sendable);

                            String n = PrefService.getString("lock");
                            int p = 0;
                            Future.doWhile(() async {
                              await Future.delayed(Duration(milliseconds: 500));

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
                                String msg = PrefService.getString('message');
                                PrefService.setString("receive", "false");
                                String newJson = '';
                                newJson = msg.replaceAll("'", "\"");
                                Map<String, dynamic> json2 =
                                    jsonDecode(newJson);
                                String function = json2['function'].toString();

                                if (function == "altaEmpleado") {
                                  String status = json2['status'].toString();

                                  if (status == "OK") {
                                    String aforo_actual = json2['data']
                                            ['aforo_actual']
                                        .toString();
                                    String aforo_max =
                                        json2['data']['aforo_max'].toString();

                                    int actual = int.parse(aforo_actual);
                                    int max = int.parse(aforo_max);
                                    showToast("Registro completado");

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              PanelPage(actual, max)),
                                    );
                                  } else {
                                    String message =
                                        json2['message'].toString();

                                    showToast(message);
                                  }
                                } else {
                                  showToast("Error en el proceso");
                                }
                              } else {
                                showToast("Error de comunicación por tópico");
                              }
                              PrefService.setString('message', '');
                            });
                          } else {
                            showToast("Exceso en el límite de carácteres");
                          }
                        } else {
                          showToast("Rellena todos los campos");
                        }
                      },
                      elevation: 0,
                      padding: EdgeInsets.all(18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Center(
                          child: Text(
                        "Registrar usuario",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      )),
                    ),
                    SizedBox(
                      height: 10,
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
