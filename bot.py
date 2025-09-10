import sqlite3
import os
import datetime
import asyncio
from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, ContextTypes, filters
from PIL import Image
import subprocess

# ===============================
# CONFIGURAÇÃO
# ===============================
TOKEN = "SEU_BOT_TOKEN"
DB_FILE = "usuarios.db"
LIMITE_GRATIS = 10

# ===============================
# BANCO DE DADOS
# ===============================
conn = sqlite3.connect(DB_FILE)
c = conn.cursor()
c.execute("""
CREATE TABLE IF NOT EXISTS usuarios (
    user_id INTEGER PRIMARY KEY,
    premium INTEGER DEFAULT 0,
    pacote TEXT DEFAULT NULL
)
""")
c.execute("""
CREATE TABLE IF NOT EXISTS limite_diario (
    user_id INTEGER PRIMARY KEY,
    contagem INTEGER DEFAULT 0,
    ultimo_reset TEXT
)
""")
conn.commit()
conn.close()

# ===============================
# FUNÇÕES DE BANCO
# ===============================
def is_premium(user_id):
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("SELECT premium FROM usuarios WHERE user_id=?", (user_id,))
    result = c.fetchone()
    conn.close()
    return result and result[0] == 1

def set_premium(user_id):
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("INSERT OR REPLACE INTO usuarios (user_id, premium) VALUES (?, 1)", (user_id,))
    conn.commit()
    conn.close()

def get_contagem(user_id):
    today = datetime.date.today().isoformat()
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("SELECT contagem, ultimo_reset FROM limite_diario WHERE user_id=?", (user_id,))
    result = c.fetchone()
    if not result:
        c.execute("INSERT INTO limite_diario (user_id, contagem, ultimo_reset) VALUES (?, 0, ?)", (user_id, today))
        conn.commit()
        conn.close()
        return 0
    contagem, ultimo_reset = result
    if ultimo_reset != today:
        c.execute("UPDATE limite_diario SET contagem=0, ultimo_reset=? WHERE user_id=?", (today, user_id))
        conn.commit()
        conn.close()
        return 0
    conn.close()
    return contagem

def increment_contagem(user_id):
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("SELECT contagem FROM limite_diario WHERE user_id=?", (user_id,))
    result = c.fetchone()
    if not result:
        c.execute("INSERT INTO limite_diario (user_id, contagem, ultimo_reset) VALUES (?, 1, ?)", (user_id, datetime.date.today().isoformat()))
    else:
        c.execute("UPDATE limite_diario SET contagem = contagem + 1 WHERE user_id=?", (user_id,))
    conn.commit()
    conn.close()

# ===============================
# COMANDOS
# ===============================
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "🌸 Olá! Eu sou o KleberSticker 🌸\n"
        "Envie uma imagem ou GIF para criar uma figurinha!\n"
        "Use /planos para ver os planos premium."
    )

async def planos(update: Update, context: ContextTypes.DEFAULT_TYPE):
    keyboard = [
        [InlineKeyboardButton("💎 Premium Mensal – R$5", url="https://linkpix.com/pagamento-mensal")],
        [InlineKeyboardButton("🌟 Premium Vitalício – R$10", url="https://linkpix.com/pagamento-vitalicio")],
        [InlineKeyboardButton("🎁 Pacote Extra – R$3", url="https://linkpix.com/pagamento-extra")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    texto = (
        "🌸 **KleberSticker – Planos de Figurinhas** 🌸\n\n"
        "✨ **Grátis** – R$ 0\n"
        f"- Até {LIMITE_GRATIS} figurinhas/dia 🖼️\n"
        "- Apenas figurinhas estáticas ❌\n"
        "- Sem pacotes personalizados 📦\n\n"
        "💎 **Premium Mensal** – R$ 5/mês\n"
        "🌟 **Premium Vitalício** – R$ 10\n"
        "🎁 **Pacote Extra** – R$ 3"
    )
    await update.message.reply_text(texto, reply_markup=reply_markup, parse_mode="Markdown")

# ===============================
# FUNÇÃO DE FIGURINHAS
# ===============================
async def criar_figurinha(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.message.from_user.id
    premium = is_premium(user_id)

    # Limite grátis
    if not premium:
        contagem = get_contagem(user_id)
        if contagem >= LIMITE_GRATIS:
            await update.message.reply_text("🚫 Limite diário atingido! Considere assinar o premium para criar figurinhas ilimitadas.")
            return
        increment_contagem(user_id)

    # Detectar se é foto ou GIF/arquivo animado
    if update.message.photo:
        # Foto → Figurinha estática
        photo = update.message.photo[-1]
        file = await photo.get_file()
        path = f"{user_id}_temp.png"
        await file.download_to_drive(path)

        output_webp = f"{user_id}_sticker.webp"
        im = Image.open(path).convert("RGBA")
        im.save(output_webp, "WEBP")

        with open(output_webp, "rb") as sticker:
            await update.message.reply_sticker(sticker)

        await update.message.reply_text("✨ Figurinha estática criada com sucesso!")

    elif update.message.document or update.message.animation:
        if not premium:
            await update.message.reply_text("🚫 Apenas usuários premium podem criar figurinhas animadas!")
            return
        doc = update.message.document or update.message.animation
        file = await doc.get_file()
        path = f"{user_id}_temp.mp4"
        await file.download_to_drive(path)

        output_webm = f"{user_id}_sticker.webm"

        subprocess.run([
            "ffmpeg", "-y", "-i", path, "-c:v", "libvpx-vp9",
            "-vf", "scale=512:512:force_original_aspect_ratio=decrease,pad=512:512:-1:-1:color=0x00000000",
            "-loop", "0", "-an", output_webm
        ])

        with open(output_webm, "rb") as sticker:
            await update.message.reply_sticker(sticker)

        await update.message.reply_text("🎬 Figurinha animada criada com sucesso!")
    else:
        await update.message.reply_text("❌ Envie uma foto ou GIF para criar uma figurinha.")

# ===============================
# COMANDO PARA TESTAR PREMIUM (PIX simulado)
# ===============================
async def liberar(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.message.from_user.id
    set_premium(user_id)
    await update.message.reply_text("🎉 Você agora é PREMIUM! Pode criar figurinhas ilimitadas e animadas!")

# ===============================
# RESET DIÁRIO AUTOMÁTICO
# ===============================
async def reset_diario():
    while True:
        conn = sqlite3.connect(DB_FILE)
        c = conn.cursor()
        today = datetime.date.today().isoformat()
        c.execute("UPDATE limite_diario SET contagem=0, ultimo_reset=?", (today,))
        conn.commit()
        conn.close()
        await asyncio.sleep(86400)  # 24h

# ===============================
# INICIALIZAÇÃO DO BOT
# ===============================
app = ApplicationBuilder().token(TOKEN).build()
app.add_handler(CommandHandler("start", start))
app.add_handler(CommandHandler("planos", planos))
app.add_handler(CommandHandler("liberar", liberar))
app.add_handler(MessageHandler(filters.PHOTO | filters.Document.ALL | filters.ANIMATION, criar_figurinha))

# Roda reset diário em paralelo
app.job_queue.run_repeating(lambda ctx: asyncio.create_task(reset_diario()), interval=86400, first=0)

print("KleberSticker rodando...")
app.run_polling()
import json
from flask import Flask, request
from telegram import Bot

app = Flask(__name__)
bot = Bot(token='SEU_BOT_TOKEN')

@app.route('/webhook', methods=['POST'])
def webhook():
    data = json.loads(request.data)
    if data['status'] == 'paid':
        user_id = data['metadata']['user_id']
        # Atualize o status do usuário para premium
        set_premium(user_id)
        # Envie uma mensagem de confirmação
        bot.send_message(user_id, "🎉 Seu pagamento foi confirmado! Agora você é PREMIUM!")
    return '', 200

def set_premium(user_id):
    # Função para atualizar o status do usuário no banco de dados
    pass

if __name__ == '__main__':
    app.run(port=5000)
