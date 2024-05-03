import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:overlay_desktop_demo2/classes.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;

class MyAppBody extends StatefulWidget {
  MyAppBody({Key? key}) : super(key: key);

  @override
  MyAppBodyState createState() => MyAppBodyState();
}

class MyAppBodyState extends State<MyAppBody> {
  WindowEffect effect = WindowEffect.transparent;
  Color color = Colors.transparent;
  InterfaceBrightness brightness =
      Platform.isMacOS ? InterfaceBrightness.auto : InterfaceBrightness.dark;
  MacOSBlurViewState macOSBlurViewState = MacOSBlurViewState.followsWindowActiveState;

  void setWindowEffect(WindowEffect? value) {
    Window.setEffect(
      effect: value!,
      color: color,
      dark: brightness == InterfaceBrightness.dark,
    );
    if (Platform.isMacOS) {
      if (brightness != InterfaceBrightness.auto) {
        Window.overrideMacOSBrightness(
          dark: brightness == InterfaceBrightness.dark,
        );
      }
    }
    this.setState(() => this.effect = value);
  }

  @override
  void initState() {
    super.initState();
    setWindowEffect(effect);
    _checkMousePos();
    _readData('demo1.json');
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  // My vars
  // Mouse pos timer
  Timer? timer1;
  double overlayWidth = 250;
  double overlayHeight = 340;
  double overlayRadius = 8;
  double overlayPadding = 20;
  Offset? mousePos;
  Offset overlayPos = const Offset(200, 200);
  bool? transBackground;
  int count = 0;
  double? screenWidth;
  double? screenHeight;
  bool isOpended = true;
  final TextEditingController _controller = TextEditingController();

  int touchedIndex = -1;

  String _value = 'Option 1';
  bool _permaTransBackground = true;

  // Stream controller for bounding boxes
  final StreamController<List<Bbox>> _streamController = StreamController();
  // Streams of data
  late final Stream<List<Bbox>> _streamData = _streamController.stream.asBroadcastStream();

  // Demo data
  late Map<String, dynamic> _demoData = {};

  // bBoxes
  List<Bbox> bBoxes = [];

  void _readData(String fileName) async {
    /*
    print('Reading json file');
    final file = File(
        'C:\\Users\\luisp\\Desktop\\projects\\Manuspect\\overlay_desktop_demo2\\assets\\data\\$fileName');
    String jsonString = await file.readAsString();
    Map<String, dynamic> jsonMap = jsonDecode(jsonString);
    ScreenBBoxSnapshot sBBSnap = ScreenBBoxSnapshot.fromJson(jsonMap);

    print('Transformed json to ScreenBBoxSnapshot -> ${sBBSnap.bboxes.length}');

    _streamController.add(sBBSnap.bboxes);
    bBoxes = sBBSnap.bboxes;
    */
    String url = '';
    try {
      var request = http.Request('GET', Uri.parse(url));
      var response = await request.send();

      response.stream.transform(utf8.decoder).listen(
        (data) {
          Map<String, dynamic> jsonMap = jsonDecode(data);
          _streamController
              .add(ScreenBBoxSnapshot.fromJson(jsonMap).bboxes); // Add data to the stream
        },
        onError: (error) {
          _streamController.addError('Error: $error'); // Send error to the stream
        },
        onDone: () {
          _streamController.close(); // Close the stream when data is done
        },
        cancelOnError: true,
      );
    } catch (e) {
      _streamController.addError('Exception caught: $e');
      _streamController.close();
    }
  }

  // Check mouse pos
  void _checkMousePos() async {
    // Fullscreen and transparent background
    Window.enterFullscreen();
    // Window.makeWindowFullyTransparent();

    // Every 100ms
    timer1 = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      // Get mouse position
      mousePos = await _getMousePos();

      // Check if cursor in bbox
      _cursorInBBox(mousePos);

      // Cursor right now in overlay
      if (_cursorInOverlay(mousePos) || _cursorInBBox(mousePos) || !_permaTransBackground) {
        // Background not already transparent
        if (transBackground == null || transBackground!) {
          Window.ignoreMouseEvents(ignore: false); // Don't ignore mouse
          setState(() {
            transBackground = false;
          });
        }

        // Cursor outside of overlay and
      } else if (transBackground == null || !transBackground!) {
        Window.ignoreMouseEvents(ignore: true); // Ignore mouse
        setState(() {
          transBackground = true;
        });
      }
    });
  }

  // Check if cursor is in overlay
  bool _cursorInOverlay(Offset? mousePos) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    return mousePos!.dx >= overlayPos.dx &&
        mousePos.dx <= overlayPos.dx + overlayWidth &&
        mousePos.dy >= overlayPos.dy - 40 &&
        mousePos.dy <= overlayPos.dy + overlayHeight;
  }

  // Cursor is in bbox
  bool _cursorInBBox(Offset? mousePos) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    for (Bbox bBox in bBoxes) {
      if ((mousePos!.dx >= bBox.xc &&
              mousePos.dx <= bBox.xc + bBox.w &&
              mousePos.dy >= bBox.yc &&
              mousePos.dy <= bBox.yc + bBox.h) ||
          bBox.visible && !_permaTransBackground) {
        // bBox visible
        if (!bBox.visible) {
          setState(() {
            bBox.visible = true;
          });
        }
        if ((mousePos.dx >= bBox.xc + bBox.w - 20 &&
                mousePos.dx <= bBox.xc + bBox.w - 2 &&
                mousePos.dy >= bBox.yc + bBox.h / 2 - 10 &&
                mousePos.dy <= bBox.yc + bBox.h / 2 + 10) ||
            !_permaTransBackground) {
          return true;
        }
      } else if (bBox.visible) {
        setState(() {
          bBox.visible = false;
        });
      }
    }

    return false;
  }

  Future<Offset> _getMousePos() async {
    return await screenRetriever.getCursorScreenPoint();
  }

  // On overlay drag end
  void _onDragEnd(DraggableDetails details) {
    setState(() {
      overlayPos = details.offset;
    });
  }

  // Close app
  void _closeApp() {
    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
  }

  // Minimize app
  void _minimizeWindow() async {
    //Window.minimizeWindow(isFullScreen: true);
    setState(() {
      overlayWidth = 50;
      overlayHeight = 50;
      overlayRadius = 25;
    });

    await Future.delayed(const Duration(milliseconds: 80));

    setState(() {
      isOpended = false;
    });
  }

  // Maximize app
  void _maximizeWindow() async {
    //Window.minimizeWindow(isFullScreen: true);
    setState(() {
      overlayWidth = 250;
      overlayHeight = 340;
      overlayRadius = 8;
    });

    await Future.delayed(const Duration(milliseconds: 90));

    setState(() {
      isOpended = true;
    });
  }

  // Draggable
  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      overlayPos += details.delta;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Stream builder
    return StreamBuilder(
      stream: _streamData,
      builder: (BuildContext context, snapshot) {
        List<Bbox>? bBoxes = snapshot.data;
        // Widgets
        List<Widget> myList = [];

        if (bBoxes != null) {
          for (Bbox bBox in bBoxes) {
            myList.add(
              Positioned(
                left: bBox.xc * 1,
                top: bBox.yc * 1,
                child: Container(
                  width: bBox.w * 1,
                  height: bBox.h * 1,
                  decoration: BoxDecoration(
                    border: Border.all(
                      style: BorderStyle.solid,
                      strokeAlign: BorderSide.strokeAlignOutside,
                      color: bBox.visible
                          ? bBox.classId == 1
                              ? Colors.red
                              : Colors.blue
                          : bBox.classId == 1
                              ? Colors.red.withOpacity(.7)
                              : Colors.blue.withOpacity(.7),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: Material(
                            color: bBox.visible
                                ? bBox.classId == 1
                                    ? Colors.red
                                    : Colors.blue
                                : bBox.classId == 1
                                    ? Colors.red.withOpacity(.7)
                                    : Colors.blue.withOpacity(.7),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(5),
                              topLeft: Radius.circular(5),
                            ),
                            child: Center(
                              child: PopupMenuButton<String>(
                                initialValue: _value,
                                child: const Icon(
                                  Icons.add_rounded,
                                  size: 15,
                                ),
                                onSelected: (newValue) {
                                  setState(() {
                                    _value = newValue;
                                    _readData(newValue);
                                    _permaTransBackground = true;
                                  });
                                },
                                onCanceled: () {
                                  setState(() {
                                    _permaTransBackground = true;
                                  });
                                },
                                onOpened: () {
                                  setState(() {
                                    _permaTransBackground = false;
                                  });
                                },
                                itemBuilder: (BuildContext context) {
                                  return <PopupMenuEntry<String>>[
                                    const PopupMenuItem(
                                      value: "demo1.json",
                                      child: Text("Option 1"),
                                    ),
                                    const PopupMenuItem(
                                      value: "demo2.json",
                                      child: Text("Option 2"),
                                    ),
                                  ];
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }

        myList.add(
          Positioned(
            left: overlayPos.dx,
            top: overlayPos.dy,
            child: AnimatedContainer(
              width: overlayWidth,
              height: overlayHeight,
              duration: const Duration(milliseconds: 150),
              curve: Easing.emphasizedAccelerate,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(overlayRadius),
              ),
              child: !isOpended
                  ? GestureDetector(
                      onPanUpdate: (DragUpdateDetails details) => _onDragUpdate(details),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              spreadRadius: 2,
                              blurRadius: 14,
                              offset: const Offset(0, 3), // changes position of shadow
                            ),
                          ],
                        ),
                        child: Center(
                          child: Material(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(overlayRadius),
                            child: InkWell(
                              onTap: _maximizeWindow,
                              borderRadius: BorderRadius.circular(overlayRadius),
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.arrow_right,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                spreadRadius: 2,
                                blurRadius: 14,
                                offset: const Offset(0, 3), // changes position of shadow
                              ),
                            ],
                          ),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onPanUpdate: (DragUpdateDetails details) =>
                                  _onDragUpdate(details),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Material(
                                      color: Colors.orange[700],
                                      borderRadius: BorderRadius.circular(9),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(9),
                                        onTap: _minimizeWindow,
                                        child: const SizedBox(
                                          width: 18,
                                          height: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Material(
                                      color: Colors.red[700],
                                      borderRadius: BorderRadius.circular(9),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(9),
                                        onTap: _closeApp,
                                        child: const SizedBox(
                                          width: 18,
                                          height: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                spreadRadius: 2,
                                blurRadius: 14,
                                offset: const Offset(0, 3), // changes position of shadow
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                const Text(
                                  'Manuspect',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  height: 60,
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      SizedBox(
                                        width: 190,
                                        child: TextField(
                                          cursorColor: Colors.grey[900],
                                          controller: _controller,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          decoration: InputDecoration(
                                            isDense: true, // Added this
                                            contentPadding:
                                                const EdgeInsets.all(8), // Added this
                                            filled: true,
                                            fillColor: Colors.white,
                                            focusColor: Colors.black,
                                            border: OutlineInputBorder(
                                              borderSide: BorderSide.none,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 35,
                                        height: 35,
                                        child: Material(
                                          color: Colors.grey[700],
                                          borderRadius: BorderRadius.circular(30),
                                          child: InkWell(
                                            onTap: () => print(_controller.text.trim()),
                                            borderRadius: BorderRadius.circular(30),
                                            child: const Icon(
                                              Icons.search,
                                              size: 17,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                spreadRadius: 2,
                                blurRadius: 14,
                                offset: const Offset(0, 3), // changes position of shadow
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(5),
                          child: Center(
                            child: PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection == null) {
                                        touchedIndex = -1;
                                        return;
                                      }
                                      touchedIndex =
                                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                                    });
                                  },
                                ),
                                startDegreeOffset: 180,
                                borderData: FlBorderData(
                                  show: false,
                                ),
                                sectionsSpace: 1,
                                centerSpaceRadius: 0,
                                sections: showingSections(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );

        return Stack(children: myList);
      },
    );
  }

  List<PieChartSectionData> showingSections() {
    return List.generate(
      4,
      (i) {
        final isTouched = i == touchedIndex;
        const color0 = Colors.blue;
        const color1 = Colors.yellow;
        const color2 = Colors.pink;
        const color3 = Colors.green;

        switch (i) {
          case 0:
            return PieChartSectionData(
              color: color0,
              value: 25,
              title: '',
              radius: 80,
              titlePositionPercentageOffset: 0.55,
              borderSide: isTouched
                  ? const BorderSide(color: Colors.white, width: 6)
                  : BorderSide(color: Colors.white.withOpacity(0)),
            );
          case 1:
            return PieChartSectionData(
              color: color1,
              value: 25,
              title: '',
              radius: 65,
              titlePositionPercentageOffset: 0.55,
              borderSide: isTouched
                  ? const BorderSide(color: Colors.white, width: 6)
                  : BorderSide(color: Colors.white.withOpacity(0)),
            );
          case 2:
            return PieChartSectionData(
              color: color2,
              value: 25,
              title: '',
              radius: 60,
              titlePositionPercentageOffset: 0.6,
              borderSide: isTouched
                  ? const BorderSide(color: Colors.white, width: 6)
                  : BorderSide(color: Colors.white.withOpacity(0)),
            );
          case 3:
            return PieChartSectionData(
              color: color3,
              value: 25,
              title: '',
              radius: 70,
              titlePositionPercentageOffset: 0.55,
              borderSide: isTouched
                  ? const BorderSide(color: Colors.white, width: 6)
                  : BorderSide(color: Colors.white.withOpacity(0)),
            );
          default:
            throw Error();
        }
      },
    );
  }
}
