import 'dart:convert';
import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

Db ? db;
String mongoLink = 'mongodb+srv://derfly:V7s8meKg1Hlvdr8e@cluster0.vaxjo.mongodb.net/Decanat?';

// Configure routes.
final _router = Router()
  ..get('/', _rootHandler)
  ..get('/echo/<message>', _echoHandler)
  ..post('/db/login', _checkLogin)
  ..post('/db/addUser', _addUser)
  ..post('/db/changeName', _changeName)
  ..post('/db/getLessons', _getWeekLessons)
  ..post('/db/getMainMessages', _getMainMessages)
  ..post('/db/getChatMessages', _getChatMessages)
  ..post('/db/sendMessage', _sendMessage);

Response _rootHandler(Request req) {
  return Response.ok('Hello, World!\n');
}

Response _echoHandler(Request request) {
  final message = request.params['message'];
  return Response.ok('$message\n');
}

Future<Response> _addUser(Request request)
async {
  var resStream = await utf8.decoder.bind(request.read()).first;
  Map<String, dynamic> user = jsonDecode(resStream);
  var users = db!.collection('users');
  if(await checkNewUser(user))
  {
    user['name'] = user['email'];
    user['group'] = "PI-421B";
    user['department'] = "Department of Software Engineering";
    users.insertOne(user);
    return Response.ok('User Added');
  }
  return Response.ok('User Existed');
}

Future<Response> _checkLogin(Request request)
async {
  var resStream = await utf8.decoder.bind(request.read()).first;
  Map<String, dynamic> user = jsonDecode(resStream);
  var users = db!.collection('users');
  var checkEmail = await users.findOne(where.eq('email', user['email']));
  var checkPassword = await users.findOne(where.eq('password', user['password']));
  if(checkEmail != null && checkPassword != null)
  {
    String responceUser = checkEmail['_id'].toString() + "@" + checkEmail['email'].toString() + "@" + checkEmail['name'].toString() + "@" + checkEmail['group'].toString() + "@" + checkEmail['department'].toString();
    return Response.ok(responceUser);
  }
  return Response.ok('False');
}

Future<Response> _changeName(Request request)
async {
  var resStream = await utf8.decoder.bind(request.read()).first;
  Map<String, dynamic> user = jsonDecode(resStream);
  var users = db!.collection('users');
  var userData = await users.updateOne(where.eq('email', user['email']), ModifierBuilder().set('name', user['name']));
  if(userData != null)
  {
    return Response.ok('True');
  }
  return Response.ok('False');
}

Future<Response> _getWeekLessons(Request request)
async {
  var resStream = await utf8.decoder.bind(request.read()).first;
  Map<String, dynamic> weekDay = jsonDecode(resStream);
  var weekDays = db!.collection('weekLessons');
  var lessons = await weekDays.findOne(where.eq('weekDay', weekDay['weekDay']));
  if(lessons != null)
  {
    String responceDay = lessons['weekDay'] + "@" + lessons['l1'] + "@" + lessons['l2'] + "@" + lessons['l3'] + "@" + lessons['l4'] + "@" + lessons['l5'] + "@" + lessons['l6'] + "@" + lessons['l7'];
    return Response.ok(responceDay);
  }
  return Response.ok('False');
}

Future<Response> _getMainMessages(Request request)
async {
  var resStream = await utf8.decoder.bind(request.read()).first;
  Map<String, dynamic> mainMessagesReq = jsonDecode(resStream);
  var mainMessages = db!.collection('MainMessages');
  var messages = mainMessages.find(where.eq('group', mainMessagesReq['group']));
  if(messages != null)
  {

    List mainMessagesList = await messages.toList();
    String mainMessagesString = ListToString(mainMessagesList);
    return Response.ok(mainMessagesString);
  }
  return Response.ok('False');
}

Future<Response> _getChatMessages(Request request)
async {
  var resStream = await utf8.decoder.bind(request.read()).first;
  Map<String, dynamic> chatMessagesReq = jsonDecode(resStream);
  var chatMessages = db!.collection('ChatMessages');
  var messages = chatMessages.find(where.eq('group', chatMessagesReq['group']));
  if(messages != null)
  {
    List chatMessagesList = await messages.toList();
    String chatMessagesString = ChatToString(chatMessagesList);
    return Response.ok(chatMessagesString);
  }
  return Response.ok('False');
}

Future<Response> _sendMessage(Request request)
async {
  var resStream = await utf8.decoder.bind(request.read()).first;
  Map<String, dynamic> message = jsonDecode(resStream);
  var ChatMessages = db!.collection('ChatMessages');
  if(await checkNewUser(message))
  {
    String hours = DateTime.now().hour.toString();
    String minutes = DateTime.now().minute.toString();
    String day = DateTime.now().day.toString();
    String month = DateTime.now().month.toString();
    String year = DateTime.now().year.toString();
    message['time'] = day+'.'+month+'.'+year+' '+hours + ':' + minutes;
    ChatMessages.insertOne(message);
    return Response.ok('True');
  }
  return Response.ok('False');
}

String ListToString(List messages)
{
  String result = "";
  for(int i = 0; i < messages.length; i++)
    {
      result = result + messages[i]['name'] + "@" + messages[i]['message'] + "@" + messages[i]['date'] + "|";
    }
  print(result);
  return result;
}

String ChatToString(List messages)
{
  String result = "";
  for(int i = 0; i < messages.length; i++)
  {
    result = result + messages[i]['name'] + "@" + messages[i]['message'] + "@" + messages[i]['time'] + "|";
  }
  print(result);
  return result;
}

Future<bool> checkNewUser(Map<String, dynamic> user)
async {
  var users = db!.collection('users');
  var checkEmail = await users.findOne(where.eq('email', user['email']).fields(['_id']));
  if(checkEmail != null)
  {
    return false;
  }
  return true;
}

void main(List<String> args) async {
  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline that logs requests.
  final _handler = Pipeline().addMiddleware(logRequests()).addHandler(_router);

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(_handler, ip, port);
  db = await Db.create(mongoLink);
  await db!.open();
  print('Server listening on port ${server.port}');
}
