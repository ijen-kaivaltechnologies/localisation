String toTitleCase(String str) {
  String result = "";
  str = str.replaceAll("_", " ");
  List<String> words = str.toLowerCase().split(" ");
  words.forEach((element) {
    element = element.trim();
    result += element[0].toUpperCase() + element.substring(1);
  });
  return result;
}

String toCamelCase(String str) {
  String result = "";
  str = str.replaceAll("_", " ");
  List<String> words = str.split(" ");
  if (words.length > 1) {
    for (int i = 0; i < words.length; i++) {
      words[i] = words[i].trim().toLowerCase();
      if (i == 0)
        result += words[i][0].toLowerCase() + words[i].substring(1);
      else
        result += words[i][0].toUpperCase() + words[i].substring(1);
    }
  } else {
    return words[0][0].toLowerCase()+words[0].substring(1);
  }
  return result;
}

main() {
  print(toTitleCase("No data strings"));
  print(toCamelCase("no data strings"));
}
