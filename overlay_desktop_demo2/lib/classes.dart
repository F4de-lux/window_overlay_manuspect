import 'dart:convert';

enum InterfaceBrightness {
  light,
  dark,
  auto,
}

// To parse this JSON data, do
//
//     final screenBBoxSnapshot = screenBBoxSnapshotFromJson(jsonString);

ScreenBBoxSnapshot screenBBoxSnapshotFromJson(String str) =>
    ScreenBBoxSnapshot.fromJson(json.decode(str));

String screenBBoxSnapshotToJson(ScreenBBoxSnapshot data) => json.encode(data.toJson());

class ScreenBBoxSnapshot {
  String sessionId;
  String screenId;
  List<Result> results;
  List<Bbox> bboxes;

  ScreenBBoxSnapshot({
    required this.sessionId,
    required this.screenId,
    required this.results,
    required this.bboxes,
  });

  factory ScreenBBoxSnapshot.fromJson(Map<String, dynamic> json) => ScreenBBoxSnapshot(
        sessionId: json["session_id"],
        screenId: json["screen_id"],
        results: List<Result>.from(json["results"].map((x) => Result.fromJson(x))),
        bboxes: List<Bbox>.from(json["bboxes"].map((x) => Bbox.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "session_id": sessionId,
        "screen_id": screenId,
        "results": List<dynamic>.from(results.map((x) => x.toJson())),
        "bboxes": List<dynamic>.from(bboxes.map((x) => x.toJson())),
      };
}

class Bbox {
  int classId;
  int xc;
  int yc;
  int w;
  int h;
  bool visible = false;

  Bbox({
    required this.classId,
    required this.xc,
    required this.yc,
    required this.w,
    required this.h,
  });

  factory Bbox.fromJson(Map<String, dynamic> json) => Bbox(
        classId: json["class_id"],
        xc: json["xc"],
        yc: json["yc"],
        w: json["w"],
        h: json["h"],
      );

  Map<String, dynamic> toJson() => {
        "class_id": classId,
        "xc": xc,
        "yc": yc,
        "w": w,
        "h": h,
      };
}

class Result {
  List<int> bbox;
  int classId;
  int id;
  String text;

  Result({
    required this.bbox,
    required this.classId,
    required this.id,
    required this.text,
  });

  factory Result.fromJson(Map<String, dynamic> json) => Result(
        bbox: List<int>.from(json["bbox"].map((x) => x)),
        classId: json["class_id"],
        id: json["id"],
        text: json["text"],
      );

  Map<String, dynamic> toJson() => {
        "bbox": List<dynamic>.from(bbox.map((x) => x)),
        "class_id": classId,
        "id": id,
        "text": text,
      };
}
