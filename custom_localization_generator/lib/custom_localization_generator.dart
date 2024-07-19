import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:custom_localization/custom_localization.dart';
import 'package:custom_localization_generator/locale_data.dart';
import 'package:custom_localization_generator/text_utills.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/source_gen.dart';

class CustomLocalizationGenerator
    extends GeneratorForAnnotation<CustomLocalization> {
  static String _getValueByKeyMethod =
      "String? byKey(String key)=> _dynamicValues[key];";

  @override
  generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    return getSource(annotation.read("jsonFileUrl").stringValue);
  }

  Future<String> getSource(String fileUrl) async {
    String jsonString = await File(fileUrl).readAsString();

    if (jsonString.isEmpty)
      throw Exception("!!!!!! Please add a json file with all strings.");
    String finalSource = "";

    Map<String, dynamic> jsonObject = jsonDecode(jsonString);
    List<LocaleData> supportedLocales = [];
    LocaleData? defaultLocale;
    jsonObject.forEach((parentKey, parentValue) {
      LocaleData localeData = LocaleData();
      localeData.languageName = parentKey;
      localeData.className = toTitleCase(parentKey);
      localeData.languageCode = parentValue["language_code"];
      localeData.scriptCode = parentValue["script_code"];
      localeData.isDefault = parentValue["is_default"];
      if (localeData.isDefault == true) defaultLocale = localeData;

      Map<String, dynamic> innerMap = parentValue;
      innerMap.forEach((innerKey, innerValue) {
        if (innerValue is Map) {
          String subClassName = toTitleCase(innerKey);
          localeData.subClassNames.add(subClassName);
          innerValue.forEach((key, value) {
            if (localeData.subClassFields[subClassName] == null)
              localeData.subClassFields[subClassName] = {};
            localeData.subClassFields[subClassName]?[key] = value;
          });
        }
      });
      supportedLocales.add(localeData);
    });

    if (defaultLocale == null)
      throw StateError(
          "!!!!!! Default locale not found, Please check JSON File!!!!!!");

    finalSource += generateRClass(supportedLocales, defaultLocale!);
    supportedLocales.forEach((element) {
      if (element == defaultLocale) {
        finalSource += generateLocaleClass(null, element);
      } else {
        finalSource += generateLocaleClass(defaultLocale, element);
      }
    });

    return finalSource;
  }

  String generateLocaleClass(LocaleData? defaultLocal, LocaleData localeData) {
    String source = "class " + localeData.className!;
    if (defaultLocal != null) source += " extends ${defaultLocal.className}";

    source += "{";
    List<String> subClasses = [];
    Map<String, Map<String, dynamic>> innerMap = localeData.subClassFields;

    innerMap.forEach((innerKey, innerValue) {
      //create child class
      String subClassSource = "class " + innerKey;
      String subClassName = innerKey;
      if (defaultLocal != null) {
        //find name of parent class from default locale
        String parentClassOfSubClass = defaultLocal.subClassNames
            .singleWhere((element) => element == innerKey);
        if (parentClassOfSubClass.isNotEmpty) {
          if (localeData.languageCode != null)
            subClassName = toTitleCase(localeData.languageCode!) + innerKey;
          subClassSource = "class $subClassName extends $parentClassOfSubClass";
        }
      }

      subClassSource += "{";

      String dynamicKeysSource =
          _getValueByKeyMethod + " Map<String,String> _dynamicValues={";
      //add fields with value if class is default locale otherwise add getters of default class fields
      //add key-value to map if key is in dynamicKeys list
      if (defaultLocal == null) {
        innerValue.forEach((key, value) {
          if (key == "dynamicKeys") {
            if (value is List<dynamic>) {
              localeData.dynamicKeys.addAll(value.map((e) => e.toString()));
            }
          } else {
            if (localeData.dynamicKeys.contains(key)) {
              dynamicKeysSource +=
                  "\"${toCamelCase(key)}\":  ${(value as String).contains("\$") ? "r\"$value\"" : "\"$value\""},";
            }
            subClassSource +=
                " String ${toCamelCase(key)} = ${(value as String).contains("\$") ? "r\"$value\"" : "\"$value\""};";
          }
        });
      } else {
        innerValue.forEach((key, value) {
          if (defaultLocal.dynamicKeys.contains(key)) {
            dynamicKeysSource +=
                "\"${toCamelCase(key)}\": ${(value as String).contains("\$") ? "r\"$value\"" : "\"$value\""},";
          }
          subClassSource +=
              "@override get ${toCamelCase(key)} => ${(value as String).contains("\$") ? "r\"$value\"" : "\"$value\""};";
        });
      }
      dynamicKeysSource += "};";
      print("final source");
      print(dynamicKeysSource);
      subClassSource += dynamicKeysSource;
      subClassSource += "}";
      subClasses.add(subClassSource);

      //add child class as fields in Locale class if its the default locale otherwise add as getter with value of child class
      if (defaultLocal == null) {
        source += "$innerKey ${toCamelCase(innerKey)}= $innerKey();";
      } else {
        source += "@override get ${toCamelCase(innerKey)}=> $subClassName(); ";
      }
    });

    if (localeData.languageCode != null)
      source +=
          "static String get languageCode=>\"${localeData.languageCode}\";";

    if (localeData.scriptCode != null)
      source += "static String get scriptCode=>\"${localeData.scriptCode}\";";
    if (localeData.languageName != null)
      source +=
          "static String get languageName=>\"${localeData.languageName}\";";

    source += "}";
    subClasses.forEach((element) {
      source += element;
    });
    var formatter = new DartFormatter();
    return formatter.format(source);
  }

  String generateRClass(
      List<LocaleData> supportedLocales, LocaleData defaultLocale) {
    String supportedLocalesSource = "{";
    supportedLocales.forEach((element) {
      supportedLocalesSource +=
          "\"${element.languageName}\":${element.className}(),";
    });
    supportedLocalesSource += "};";

    String source = '''
  class R {
  static ${defaultLocale.className} get string => _getDefaultLocal();

  static String? _appLocale;

  static Map<String, ${defaultLocale.className}> _supportedLocales = $supportedLocalesSource

  static ${defaultLocale.className} _getDefaultLocal() {
    //return default strings if locale is not set

    if (_appLocale == null) return ${defaultLocale.className}();

    //throw exception to notify given local is not found or not generated by the generator

    if (!_supportedLocales.containsKey(_appLocale))
      throw Exception(
          \"\$_appLocale is not found.\\n Make sure you have added this locale in JSON file\\n Try running flutter pub run build_runner\");

    //return locale from map

    return _supportedLocales[_appLocale]!;
  }

  static void changeLocale(String newLocale) {
    _appLocale = newLocale;
  }
}
 ''';

    var formatter = new DartFormatter();
    return formatter.format(source);
  }
}
