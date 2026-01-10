import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

void main() async {
  // Kelgan har qanday so'rovni konsolga chiqaruvchi handler
  var handler = const Pipeline().addMiddleware(logRequests()).addHandler((Request req) async {
    final body = await req.readAsString();
    print('\n🚀 [LOCAL SERVER] YANGI WEBHOOK KELDI!');
    print('Method: ${req.method}');
    print('Path: ${req.url.path}');
    print('Body: $body');
    print('-----------------------------------\n');
    
    return Response.ok('DHOOK orqali xabar qabul qilindi!');
  });

  // 8000-portda ishga tushiramiz
  await io.serve(handler, 'localhost', 8000);
  print('✅ Test listener http://localhost:8000 da ishlayapti...');
}