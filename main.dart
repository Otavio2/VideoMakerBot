import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

final botToken = 'SEU_BOT_TOKEN_AQUI'; // coloque seu token aqui
final donoId = 'SEU_CHAT_ID_AQUI'; // coloque seu id de usuário aqui
final usuariosFile = File('usuarios.json');

Future<Set<String>> lerUsuariosLiberados() async {
  if (!await usuariosFile.exists()) {
    await usuariosFile.writeAsString(jsonEncode({'liberados': []}));
  }
  final data = jsonDecode(await usuariosFile.readAsString());
  return Set<String>.from(data['liberados']);
}

Future<void> salvarUsuariosLiberados(Set<String> ids) async {
  final data = {'liberados': ids.toList()};
  await usuariosFile.writeAsString(jsonEncode(data));
}

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('Webhook rodando na porta 8080...');

  await for (HttpRequest request in server) {
    // 🔹 Health check do Render
    if (request.method == 'GET') {
      request.response.statusCode = 200;
      request.response.write('Bot rodando OK ✅');
      await request.response.close();
      continue;
    }

    // 🔹 Tratamento do webhook do Telegram
    if (request.method == 'POST') {
      final content = await utf8.decoder.bind(request).join();
      final data = jsonDecode(content);

      if (data['message'] != null || data['callback_query'] != null) {
        String userId = '';
        String text = '';
        String? callbackId;

        // Mensagem normal
        if (data['message'] != null) {
          final message = data['message'];
          text = message['text'] ?? '';
          userId = message['from']['id'].toString();
        }

        // Clique em botão inline
        if (data['callback_query'] != null) {
          final query = data['callback_query'];
          text = query['data'] ?? '';
          userId = query['from']['id'].toString();
          callbackId = query['id'];
          if (callbackId != null) await answerCallback(callbackId);
        }

        final usuariosLiberados = await lerUsuariosLiberados();

        if (text == '/start') {
          await sendStartMessage(userId, usuariosLiberados.contains(userId));
        } else if (['paisagem', 'relax', 'nostalgia', 'musica'].contains(text)) {
          if (!usuariosLiberados.contains(userId)) {
            await sendMessage(userId,
                '❌ Você não tem permissão para gerar vídeos. Contate o dono para liberação.');
            return;
          }
          String categoria = '';
          switch (text) {
            case 'paisagem':
              categoria = 'Paisagem';
              break;
            case 'relax':
              categoria = 'Relaxamento';
              break;
            case 'nostalgia':
              categoria = 'Nostalgia';
              break;
            case 'musica':
              categoria = 'Música instrumental';
              break;
          }
          await gerarVideo(userId, categoria);
        } else if (text == 'liberar_usuario' && userId == donoId) {
          await sendMessage(userId, 'Envie o ID ou @username do usuário que deseja liberar:');
        } else if (text == 'remover_usuario' && userId == donoId) {
          await sendMessage(userId, 'Envie o ID ou @username do usuário que deseja remover:');
        } else if (text.startsWith('@') || RegExp(r'^\d+$').hasMatch(text)) {
          if (userId == donoId) {
            String id = text.replaceAll('@', '');
            if (usuariosLiberados.contains(id)) {
              usuariosLiberados.remove(id);
              await salvarUsuariosLiberados(usuariosLiberados);
              await sendMessage(userId, '❌ Usuário $id removido da geração de vídeos.');
            } else {
              usuariosLiberados.add(id);
              await salvarUsuariosLiberados(usuariosLiberados);
              await sendMessage(userId, '✅ Usuário $id liberado para gerar vídeos!');
            }
          }
        }
      }

      request.response.statusCode = 200;
      await request.response.close();
    }
  }
}

// 📌 Mensagem de boas-vindas com botões
Future<void> sendStartMessage(String chatId, bool isLiberado) async {
  final msg = """
🎬 Olá! Eu sou o VideoMakerBot.

💡 O que eu faço:
- Gero vídeos automáticos com imagens e músicas livres de direitos autorais.
- Adiciono legendas e formato pronto para redes sociais.
- Qualquer um pode explorar o menu, mas só usuários liberados geram vídeos completos.

⚠️ Se você não estiver liberado, peça acesso ao dono do bot.
""";

  final keyboard = [
    [
      {'text': '🌄 Paisagem', 'callback_data': 'paisagem'},
      {'text': '🧘 Relax', 'callback_data': 'relax'}
    ],
    [
      {'text': '🕰 Nostalgia', 'callback_data': 'nostalgia'},
      {'text': '🎵 Música', 'callback_data': 'musica'}
    ]
  ];

  if (chatId == donoId) {
    keyboard.add([
      {'text': '🔑 Liberar Usuário', 'callback_data': 'liberar_usuario'},
      {'text': '❌ Remover Usuário', 'callback_data': 'remover_usuario'}
    ]);
  }

  final replyMarkup = jsonEncode({'inline_keyboard': keyboard});

  final url =
      'https://api.telegram.org/bot$botToken/sendMessage?chat_id=$chatId&text=${Uri.encodeComponent(msg)}&reply_markup=${Uri.encodeComponent(replyMarkup)}';
  await http.get(Uri.parse(url));
}

// 📌 Responde callback (remove "loading" nos botões)
Future<void> answerCallback(String callbackId) async {
  if (callbackId.isEmpty) return;
  final url =
      'https://api.telegram.org/bot$botToken/answerCallbackQuery?callback_query_id=$callbackId';
  await http.get(Uri.parse(url));
}

// 📌 Placeholder de geração de vídeo
Future<void> gerarVideo(String userId, String categoria) async {
  await sendMessage(userId, '🚧 Gerando vídeo de "$categoria"... (função em desenvolvimento)');
}

// 📌 Enviar mensagem simples
Future<void> sendMessage(String chatId, String text) async {
  final url =
      'https://api.telegram.org/bot$botToken/sendMessage?chat_id=$chatId&text=${Uri.encodeComponent(text)}';
  await http.get(Uri.parse(url));
}
