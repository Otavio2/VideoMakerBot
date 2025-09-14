import 'dart:convert';
import 'dart:io';

// 🔑 coloque aqui seu TOKEN do bot
const String botToken = String.fromEnvironment('BOT_TOKEN', defaultValue: 'COLOQUE_SEU_TOKEN_AQUI');
// 🔑 coloque aqui o ID do dono (ou deixe vazio e você adiciona depois pelo botão)
const String donoId = String.fromEnvironment('OWNER_ID', defaultValue: '');

final Set<String> usuariosLiberados = {};
final Set<String> usuariosBloqueados = {};

Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('Webhook rodando na porta $port...');

  await for (HttpRequest request in server) {
    if (request.method == 'GET') {
      // healthcheck do Render
      request.response.statusCode = 200;
      request.response.write('Bot rodando OK ✅');
      await request.response.close();
      continue;
    }

    if (request.method == 'POST') {
      final content = await utf8.decoder.bind(request).join();
      final data = jsonDecode(content);

      if (data.containsKey('message')) {
        final msg = data['message'];
        final userId = msg['from']['id'].toString();
        final text = msg['text'] ?? '';

        if (text == '/start') {
          await sendMessage(userId, '''
🤖 *Bem-vindo ao VideoMaker Bot!*

Este bot pode:
- Criar vídeos automáticos com imagens, músicas e legendas CC0 🎬
- Enviar conteúdos prontos para redes sociais 📲
- Mostrar exemplos antes de liberar a geração 🔒

⚙️ O dono pode liberar ou remover usuários da geração de vídeos.
          ''',
              replyMarkup: {
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
            await sendMessage(userId, '🚫 Você não tem permissão para gerar vídeos. Peça ao dono do bot.');
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
  }
}

// Função de enviar mensagem
Future<void> sendMessage(String chatId, String text, {Map<String, dynamic>? replyMarkup}) async {
  final uri = Uri.parse("https://api.telegram.org/bot$botToken/sendMessage");
  final body = {
    "chat_id": chatId,
    "text": text,
    "parse_mode": "Markdown",
  };
  if (replyMarkup != null) {
    body["reply_markup"] = jsonEncode(replyMarkup);
  }
  await HttpClient().postUrl(uri).then((req) {
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
    return req.close();
  });
}

// Responder cliques de botão
Future<void> answerCallback(String callbackId) async {
  final uri = Uri.parse("https://api.telegram.org/bot$botToken/answerCallbackQuery");
  final body = {"callback_query_id": callbackId};
  await HttpClient().postUrl(uri).then((req) {
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
    return req.close();
  });
}

// Função simulada de gerar vídeo
Future<void> gerarVideo(String userId, String categoria) async {
  // ⚠️ Aqui depois podemos integrar imagens CC0 + música + legendas
  await sendMessage(userId, "🎬 Gerando vídeo automático na categoria: $categoria ...");
  await Future.delayed(Duration(seconds: 2));
  await sendMessage(userId, "✅ Vídeo pronto! (simulação)");
}
