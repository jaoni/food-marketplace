import 'dart:convert';
import 'dart:io';

/// A real backend response, saved in test/fixtures/ with curl.
String fixtureText(String name) => File('test/fixtures/$name.json').readAsStringSync();

/// The same, decoded from JSON.
dynamic fixture(String name) => jsonDecode(fixtureText(name));
