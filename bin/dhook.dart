import 'package:args/args.dart';
import 'package:dhook/dhook.dart';

void main(List<String> arguments) async {
  final parser = ArgParser();

  // Server command
  final serverParser = ArgParser()
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: '3000',
      help: 'Port to run the relay server on',
    );
  parser.addCommand('server', serverParser);

  // Client command
  final clientParser = ArgParser()
    ..addOption('server', abbr: 's', help: 'DHOOK Relay server URL (ws://...)')
    ..addOption(
      'target',
      abbr: 't',
      help: 'Local target URL (http://localhost:8000)',
    );
  parser.addCommand('client', clientParser);

  try {
    final results = parser.parse(arguments);

    if (results.command?.name == 'server') {
      final port = int.parse(results.command!['port']);
      final server = RelayServer(port: port);
      await server.start();
    } else if (results.command?.name == 'client') {
      final serverUrl = results.command!['server'];
      final targetUrl = results.command!['target'];

      if (serverUrl == null || targetUrl == null) {
        print('Error: --server and --target options are required!');
        return;
      }

      final agent = CliAgent(serverUrl: serverUrl, targetUrl: targetUrl);
      await agent.start();
    } else {
      print('DHOOK - Webhook Relay Tool');
      print('\nCommands:');
      print('  server  - Start the relay server');
      print('  client  - Connect CLI agent to receive webhooks');
      print('\nFor help: dhook <command> --help');
    }
  } catch (e) {
    print('Error: $e');
  }
}
