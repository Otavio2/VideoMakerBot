import os
import json
import logging
from datetime import datetime
import pytz
from telegram import Update, Sticker
from telegram.ext import ApplicationBuilder, ContextTypes, MessageHandler, filters
from apscheduler.schedulers.asyncio import AsyncIOScheduler

# =========================
# CONFIGURAÇÃO
# =========================

BOT_TOKEN = os.getenv("BOT_TOKEN", "COLOQUE_SEU_TOKEN_AQUI")
OWNER_ID = int(os.getenv("OWNER_ID", "123456789"))  # seu ID numérico
TIMEZONE = pytz.timezone("America/Sao_Paulo")

# Arquivo para salvar dados no disco
DATA_FILE = "dados.json"
LIMITE_FIGURINHAS = 50

# Cache em memória
dados = {"figurinhas": [], "favoritos": []}

# =========================
# LOGGING
# =========================
logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# =========================
# FUNÇÕES DE BACKUP
# =========================
def carregar_dados():
    global dados
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r") as f:
                dados = json.load(f)
            logger.info("📂 Dados carregados do disco")
        except Exception as e:
            logger.error(f"Erro ao carregar dados: {e}")

def salvar_dados():
    try:
        with open(DATA_FILE, "w") as f:
            json.dump(dados, f)
        logger.info("💾 Backup de dados salvo")
    except Exception as e:
        logger.error(f"Erro ao salvar dados: {e}")

# =========================
# HANDLERS
# =========================
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id == OWNER_ID:
        await update.message.reply_text("🤖 Bot do dono online!")
    else:
        await update.message.reply_text("🤖 Bot online!")

async def salvar_figurinha(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.message.sticker:
        fig_id = update.message.sticker.file_id
        if fig_id not in dados["figurinhas"]:
            if len(dados["figurinhas"]) >= LIMITE_FIGURINHAS:
                dados["figurinhas"].pop(0)  # Remove a mais antiga
            dados["figurinhas"].append(fig_id)
            await update.message.reply_text("✅ Figurinha salva!")
        else:
            await update.message.reply_text("⚠️ Essa figurinha já está salva.")

async def mensagem_texto(update: Update, context: ContextTypes.DEFAULT_TYPE):
    texto = update.message.text.lower()

    # Bloqueia conteúdo adulto
    proibidas = ["porn", "sexo", "nude"]
    if any(p in texto for p in proibidas):
        await update.message.delete()
        await update.message.reply_text("🚫 Conteúdo proibido!")
        return

    # Resposta automática
    if "oi" in texto:
        await update.message.reply_text("Oi! 👋")
    elif "figura" in texto and dados["figurinhas"]:
        await update.message.reply_sticker(dados["figurinhas"][0])

# =========================
# TAREFA AUTOMÁTICA
# =========================
async def tarefa_diaria():
    agora = datetime.now(TIMEZONE).strftime("%H:%M:%S")
    logger.info(f"⏰ Executando tarefa diária às {agora}")
    salvar_dados()

# =========================
# MAIN
# =========================
def main():
    carregar_dados()

    app = ApplicationBuilder().token(BOT_TOKEN).build()

    app.add_handler(MessageHandler(filters.COMMAND & filters.Regex("^/start$"), start))
    app.add_handler(MessageHandler(filters.Sticker.ALL, salvar_figurinha))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, mensagem_texto))

    scheduler = AsyncIOScheduler(timezone=TIMEZONE)
    scheduler.add_job(tarefa_diaria, "interval", hours=24)
    scheduler.start()

    logger.info("🚀 Bot iniciado")
    app.run_polling()

if __name__ == "__main__":
    main()
