import 'dart:io';
import 'package:args/args.dart';
import 'package:dhook/dhook.dart';

const String version = '1.0.0';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('version', abbr: 'v', negatable: false, help: 'Show version')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  // Server command
  final serverParser = ArgParser()
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: '3000',
      help: 'Port to run the relay server on',
    )
    ..addFlag(
      'no-auth',
      help: 'Disable API key authentication (NOT recommended)',
      defaultsTo: false,
    )
    ..addOption('keys-file', help: 'Path to API keys storage file')
    ..addFlag('help', abbr: 'h', negatable: false);
  parser.addCommand('server', serverParser);

  // Client command
  final clientParser = ArgParser()
    ..addOption('server', abbr: 's', help: 'DHOOK Relay server URL (ws://...)')
    ..addOption(
      'target',
      abbr: 't',
      help: 'Local target URL (http://localhost:8000)',
    )
    ..addOption('api-key', abbr: 'k', help: 'API key for authentication')
    ..addFlag('help', abbr: 'h', negatable: false);
  parser.addCommand('client', clientParser);

  try {
    final results = parser.parse(arguments);

    // Version flag
    if (results['version'] == true) {
      print('dhook version $version');
      return;
    }

    // Help flag or no command
    if (results['help'] == true || results.command == null) {
      _printBanner();
      _printUsage();
      return;
    }

    // Server command
    if (results.command?.name == 'server') {
      if (results.command!['help'] == true) {
        _printServerHelp();
        return;
      }
      final port = int.parse(results.command!['port']);
      final disableAuth = results.command!['no-auth'] == true;
      final keysFile = results.command!['keys-file'] as String?;

      DLogger.banner('DHOOK Server', version, port);
      if (disableAuth) {
        print('⚠️  WARNING: Authentication DISABLED (not recommended)');
      } else {
        print('🔐 API Key authentication enabled');
      }

      final server = RelayServer(
        port: port,
        enableAuth: !disableAuth,
        apiKeyStoragePath: keysFile ?? (!disableAuth ? 'keys.json' : null),
      );
      await server.start();
    }
    // Client command
    else if (results.command?.name == 'client') {
      if (results.command!['help'] == true) {
        _printClientHelp();
        return;
      }
      final serverUrl = results.command!['server'];
      final targetUrl = results.command!['target'];
      final apiKey = results.command!['api-key'] as String?;

      if (serverUrl == null || targetUrl == null) {
        DLogger.error('Missing required options: --server and --target');
        _printClientHelp();
        exit(1);
      }

      _printClientBanner(serverUrl, targetUrl, apiKey: apiKey);
      final agent = CliAgent(
        serverUrl: serverUrl,
        targetUrl: targetUrl,
        apiKey: apiKey,
      );
      await agent.start();
    }
  } catch (e) {
    DLogger.error('$e');
    exit(1);
  }
}

void _printBanner() {
  const cyan = '\x1B[36m';
  const bold = '\x1B[1m';
  const reset = '\x1B[0m';
  const dim = '\x1B[2m';

  print('''
$cyan$bold
  ██████╗ ██╗  ██╗ ██████╗  ██████╗ ██╗  ██╗
  ██╔══██╗██║  ██║██╔═══██╗██╔═══██╗██║ ██╔╝
  ██║  ██║███████║██║   ██║██║   ██║█████╔╝ 
  ██║  ██║██╔══██║██║   ██║██║   ██║██╔═██╗ 
  ██████╔╝██║  ██║╚██████╔╝╚██████╔╝██║  ██╗
  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝
$reset
  ${dim}Webhook Relay Service$reset  ${dim}v$version$reset
''');
}

void _printUsage() {
  const green = '\x1B[32m';
  const yellow = '\x1B[33m';
  const reset = '\x1B[0m';
  const bold = '\x1B[1m';
  const dim = '\x1B[2m';

  print('''
${bold}USAGE:$reset
  dhook <command> [options]

${bold}COMMANDS:$reset
  ${green}server$reset    Start the relay server
  ${green}client$reset    Connect to relay and forward webhooks locally

${bold}OPTIONS:$reset
  $yellow-v, --version$reset    Show version
  $yellow-h, --help$reset       Show this help

${bold}EXAMPLES:$reset
  $dim# Start server on port 3000$reset
  dhook server --port 3000

  $dim# Connect client to relay$reset
  dhook client --server ws://your-server.com:3000/ws/my-channel --target http://localhost:8000

${dim}Documentation: https://github.com/alisheraxmedov/dhook$reset
''');
}

void _printServerHelp() {
  const yellow = '\x1B[33m';
  const reset = '\x1B[0m';
  const bold = '\x1B[1m';
  const dim = '\x1B[2m';

  print('''
${bold}DHOOK SERVER$reset

Start the webhook relay server.

${bold}USAGE:$reset
  dhook server [options]

${bold}OPTIONS:$reset
  $yellow-p, --port$reset <port>     Port to run the server on (default: 3000)
  $yellow    --no-auth$reset        Disable API key authentication (NOT recommended)
  $yellow    --keys-file$reset      Path to API keys storage file
  $yellow-h, --help$reset           Show this help

${bold}EXAMPLES:$reset
  ${dim}dhook server --port 3000$reset
  ${dim}dhook server --port 3000 --no-auth  # Local dev only!$reset
''');
}

void _printClientHelp() {
  const yellow = '\x1B[33m';
  const reset = '\x1B[0m';
  const bold = '\x1B[1m';
  const dim = '\x1B[2m';

  print('''
${bold}DHOOK CLIENT$reset

Connect to a relay server and forward webhooks to localhost.

${bold}USAGE:$reset
  dhook client [options]

${bold}OPTIONS:$reset
  $yellow-s, --server$reset <url>   WebSocket URL of the relay server (required)
  $yellow-t, --target$reset <url>   Local URL to forward webhooks to (required)
  $yellow-k, --api-key$reset        API key for authentication
  $yellow-h, --help$reset           Show this help

${bold}EXAMPLES:$reset
  ${dim}dhook client \\
    --server ws://your-server.com:3000/ws/my-channel \\
    --target http://localhost:8000$reset
  ${dim}dhook client -s wss://server/ws/ch -t http://localhost:8000 -k dhk_xxx$reset
''');
}

void _printClientBanner(String serverUrl, String targetUrl, {String? apiKey}) {
  const cyan = '\x1B[36m';
  const green = '\x1B[32m';
  const yellow = '\x1B[33m';
  const reset = '\x1B[0m';
  const bold = '\x1B[1m';
  const dim = '\x1B[2m';

  final authStatus = apiKey != null
      ? '$green●$reset Auth:   ${yellow}API Key$reset'
      : '$dim○ Auth:   None$reset';

  print('''
$dim──────────────────────────────────────────────────$reset
  $bold${cyan}DHOOK Client$reset ${dim}v$version$reset
  $green●$reset Relay:  $bold$serverUrl$reset
  $green●$reset Target: $bold$targetUrl$reset
  $authStatus
$dim──────────────────────────────────────────────────$reset
''');
}
