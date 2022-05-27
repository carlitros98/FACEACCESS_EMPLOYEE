import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:capacity_access_employee/ClientClass.dart';
import 'package:capacity_access_employee/main.dart';
import 'package:capacity_access_employee/themes/theme_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:preferences/preference_service.dart';
import 'package:provider/provider.dart';
import 'package:typed_data/typed_data.dart';

class PanelPage extends StatefulWidget {
  late int actual;
  late int max;

  PanelPage(int aforoActual, int aforoMax) {
    this.actual = aforoActual;
    this.max = aforoMax;
  }

  @override
  _PanelPage createState() => _PanelPage(actual, max);
}

Map<int, Color> color = {
  50: Color.fromRGBO(0, 120, 120, .1),
  100: Color.fromRGBO(0, 120, 120, .2),
  200: Color.fromRGBO(0, 120, 120, .3),
  300: Color.fromRGBO(0, 120, 120, .4),
  400: Color.fromRGBO(0, 120, 120, .5),
  500: Color.fromRGBO(0, 120, 120, .6),
  600: Color.fromRGBO(0, 120, 120, .7),
  700: Color.fromRGBO(0, 120, 120, .8),
  800: Color.fromRGBO(0, 120, 120, .9),
  900: Color.fromRGBO(0, 120, 120, 1),
};

class _PanelPage extends State<PanelPage> {
  late MqttClient subclient;
  double percent = 0;

  int aforo_actual = 0;
  int aforo_max = 1;

  String topic_sub = "receiveServerEmpleado";

  String sender = "";

  List<ClientClass> ultimos = [];

  _PanelPage(int actual, int max) {
    aforo_actual = actual;
    aforo_max = max;
    percent = (aforo_actual / aforo_max);
  }

  @override
  void initState() {
    super.initState();
    var rng = Random();
    String mqttBroker = PrefService.getString("broker");
    sender = PrefService.getString("sender");
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
      client.subscribe(topic_a, MqttQos.atLeastOnce);
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        try {
          final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
          final String pt =
              MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

          String newJson = '';
          newJson = pt.replaceAll("'", "\"");
          Map<String, dynamic> json2 = jsonDecode(newJson);

          String receiver = json2['receiver'].toString();
          String function = json2['function'].toString();

          if (receiver == "broadcast") {
            if (function == "updateAforo") {
              print(json2['data'].toString());
              final actual = json2['data']['aforo_actual'];
              final maximo = json2['data']['aforo_maximo'];

              final nombre_completo = json2['data']['nombre'].toString();
              final cert_id = json2['data']['certificate'].toString();
              final act = json2['data']['action'].toString();

              final photo = json2['data']['photo'].toString();

              final now = new DateTime.now();
              String formatter = DateFormat.Hm().format(now);
              ClientClass c = ClientClass(
                  nombre_completo: nombre_completo,
                  cert_id: cert_id,
                  act: act,
                  photo: photo,
                  hour: formatter);

              var aux = ultimos;
              ultimos = [];
              ultimos.add(c);
              aux.forEach((element) {
                if (aux.last == element && aux.length == 10) {
                } else {
                  ultimos.add(element);
                }
              });

              setState(() {});

              aforo_actual = actual;
              aforo_max = maximo;
              print("1404:" +
                  aforo_actual.toString() +
                  ";" +
                  aforo_max.toString());
              percent = (aforo_actual / aforo_max);

              setState(() {});
            }
          }
        } on Exception {}
      });
    } else {
      client.disconnect();
    }

    return 0;
  }

  Future<bool> _onWillPop() async {
    return false;
  }

  Image imageFromBase64String(String base64String) {
    return Image.memory(base64Decode(base64String));
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return new WillPopScope(
        child: Consumer<ThemeModel>(
            builder: (context, ThemeModel themeNotifier, child) {
          themeNotifier.isDark = false;

          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [],
            ),
            body: Center(
              child: Container(
                width: size.width,
                height: size.height,
                padding: EdgeInsets.only(
                    left: 20, right: 20, bottom: size.height * 0.05, top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 50,
                        ),
                        Text(
                          'AFORO',
                          style: TextStyle(
                              height: 0,
                              fontSize: 50,
                              fontWeight: FontWeight.bold),
                        ),
                        SizedBox(
                          height: 64.0,
                        ),
                        Text(
                          '$aforo_actual / $aforo_max',
                          style: TextStyle(
                              height: 0,
                              fontSize: 35,
                              fontWeight: FontWeight.bold),
                        ),
                        SizedBox(
                          height: 64.0,
                        ),
                        LinearPercentIndicator(
                          width: MediaQuery.of(context).size.width - 40,
                          barRadius: Radius.lerp(
                              Radius.circular(10), Radius.circular(10), 50),
                          animation: false,
                          lineHeight: 20.0,
                          animationDuration: 1400,
                          percent: percent,
                          progressColor: (percent! < 0.65)
                              ? Colors.green
                              : ((percent! > 0.65 && percent! < 0.9)
                                  ? Colors.amber
                                  : Colors.red),
                        ),
                        SizedBox(
                          height: 27.0,
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        physics: AlwaysScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: ultimos.length,
                        itemBuilder: (_, index) {
                          Icon ic = (ultimos[index].act == "in")
                              ? Icon(Icons.arrow_circle_right,
                                  size: 30, color: Colors.green)
                              : Icon(Icons.arrow_circle_left,
                                  size: 30, color: Colors.red);
                          //get Image from BASE64
                          return Card(
                            child: ListTile(
                              leading: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [ic, Text(ultimos[index].hour)]),
                              trailing:
                                  imageFromBase64String(ultimos[index].photo),
                              title: Text(ultimos[index].nombre_completo),
                              subtitle: Text(ultimos[index].cert_id),
                              onTap: () {},
                            ),
                          );
                        },
                      ),
                      /*SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListView.builder(
                              physics: NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemBuilder: (BuildContext, index) {
                                Icon ic = (ultimos[index].act == "in")
                                    ? Icon(Icons.arrow_circle_left,
                                        size: 30, color: Colors.green)
                                    : Icon(Icons.arrow_circle_left,
                                        size: 30, color: Colors.red);
                                //get Image from BASE64
                                return Card(
                                  child: ListTile(
                                    leading: ic,
                                    trailing: CircleAvatar(
                                      backgroundImage:
                                          AssetImage("assets/images/icono.png"),
                                    ),
                                    title: Text(ultimos[index].nombre_completo),
                                    subtitle: Text(ultimos[index].cert_id),
                                    onTap: () {},
                                  ),
                                );
                              },
                              itemCount: ultimos.length,
                            )
                          ],
                        )),*/
                    )
                  ],
                ),
              ),
            ),
          );
        }),
        onWillPop: _onWillPop);
  }
}
