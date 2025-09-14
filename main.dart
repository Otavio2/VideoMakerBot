import 'dart:convert';
import 'dart:io';

const String botToken =
    String.fromEnvironment('BOT_TOKEN', defaultValue: 'COLOQUE_SEU_TOKEN_AQUI');
const String donoId =
    String.fromEnvironment('OWNER_ID', defaultValue: 'COLOQUE_SEU_ID_AQUI');

final Set<String> usuariosLiberados = {};
final Set<String> usuariosBloqueados = {};

Future<void> main() async {
  // Porta dinâmica fornecida pelo Render
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('Webhook rodando na porta $port...');

  await for (HttpRequest request in server) {
    try {
      if (request.method == 'GET') {
        // Healthcheck do Render
        request.response.statusCode = 200;
        request.response.write('Bot rodando OK ✅');
        await request.response.close();
        continue;
      }

      if (request.method == 'POST') {
        final content = await utf8.decoder.bind(request).join();
        print('[DEBUG] Conteúdo do POST: $content');

        final data = jsonDecode(content);
        print('[LOG] Recebido webhook: $data');

        // Mensagens de texto
        if (data.containsKey('message')) {
          final msg = data['message'];
          final userId = msg['from']['id'].toString();
          final text = msg['text'] ?? '';

          print('[DEBUG] Mensagem de $userId: $text');

          if (text == '/start') {
            await sendMessage(userId, '''
🤖 *Bem-vindo ao VideoMaker Bot!*

💡 Funcionalidades:
- Criar vídeos automáticos com imagens e músicas CC0
- Adicionar legendas
- Conteúdos prontos para redes sociais
- Menu de teste e liberação de usuários
            ''', replyMarkup: {
              "inline_keyboard": [
                [
                  {"text": "🎥 Gerar Vídeo", "callback_data": "gerar_video"},
                ],
                [
                  {"text": "✅ Liberar Usuário", "callback_data": "liberar"},
                  {"text": "❌ Remover Usuário", "callback_data": "remover"},
                ]
              ]
            });
          }
        }

        // Callback de botões
        if (data.containsKey('callback_query')) {
          final callback = data['callback_query'];
          final callbackId = callback['id'];
          final userId = callback['from']['id'].toString();
          final dataCb = callback['data'];

          await answerCallback(callbackId);

          if (dataCb == 'gerar_video') {
            if (userId == donoId || usuariosLiberados.contains(userId)) {
              await gerarVideo(userId, "paisagem");
            } else {
              await sendMessage(
                  userId, '🚫 Você não tem permissão para gerar vídeos.');
            }
          }

          if (dataCb == 'liberar' && userId == donoId) {
            await sendMessage(userId, 'Envie o ID do usuário que deseja liberar:');
          }

          if (dataCb == 'remover' && userId == donoId) {
            await sendMessage(userId, 'Envie o ID do usuário que deseja remover:');
          }
        }

        request.response.statusCode = 200;
        await request.response.close();
      }
    } catch (e, s) {
      print('[ERRO] $e\n$s');
      try {
        request.response.statusCode = 500;
        await request.response.close();
      } catch (_) {}
    }
  }
}

// Envia mensagens para Telegram
Future<void> sendMessage(String chatId, String text,
    {Map<String, dynamic>? replyMarkup}) async {
  final uri = Uri.parse("https://api.telegram.org/bot$botToken/sendMessage");
  final body = {
    "chat_id": chatId,
    "text": text,
    "parse_mode": "Markdown",
  };
  if (replyMarkup != null) {
    body["reply_markup"] = jsonEncode(replyMarkup);
  }

  try {
    await HttpClient().postUrl(uri).then((req) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      return req.close();
    });
  } catch (e) {
    print('[ERRO] Falha ao enviar mensagem: $e');
  }
}

// Responde callbacks de botões
Future<void> answerCallback(String callbackId) async {
  final uri =
      Uri.parse("https://api.telegram.org/bot$botToken/answerCallbackQuery");
  final body = {"callback_query_id": callbackId};
  try {
    await HttpClient().postUrl(uri).then((req) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      return req.close();
    });
  } catch (e) {
    print('[ERRO] Falha ao responder callback: $e');
  }
}

// Simula geração de vídeo
Future<void> gerarVideo(String userId, String categoria) async {
  await sendMessage(userId, "🎬 Gerando vídeo automático na categoria: $categoria ...");
  await Future.delayed(Duration(seconds: 2));
  await sendMessage(userId, "✅ Vídeo pronto! (simulação)");
}
