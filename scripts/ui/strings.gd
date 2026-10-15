class_name Strings
extends RefCounted
## The interface text in three languages: English, Brazilian Portuguese and Spanish.
## Registered with the TranslationServer at start, so tr(key) follows the chosen language.
## Chronicle entries and event cards are not translated yet.

const LANGUAGES := ["en", "pt_BR", "es"]
const LANGUAGE_NAMES := {"en": "English", "pt_BR": "Português (Brasil)", "es": "Español"}

const TABLE := {
	"menu.title": ["The Annals", "Os Anais", "Los Anales"],
	"menu.subtitle": ["A monastery at the end of the world", "Um mosteiro no fim do mundo", "Un monasterio al fin del mundo"],
	"menu.continue": ["Continue", "Continuar", "Continuar"],
	"menu.new_house": ["New house", "Nova casa", "Casa nueva"],
	"menu.load_house": ["Load house", "Abrir casa", "Abrir casa"],
	"menu.settings": ["Settings", "Configurações", "Ajustes"],
	"menu.quit": ["Quit", "Sair", "Salir"],
	"menu.back": ["Back", "Voltar", "Volver"],
	"menu.quit_text": ["Quit The Annals? Your houses are saved.", "Sair de Os Anais? Suas casas estão salvas.", "¿Salir de Los Anales? Tus casas están guardadas."],
	"menu.version": ["Version 0.6", "Versão 0.6", "Versión 0.6"],
	"slots.new_title": ["Start a new house in which slot?", "Em qual vaga começar uma nova casa?", "¿En qué ranura empezar una casa nueva?"],
	"slots.load_title": ["Open which house?", "Qual casa abrir?", "¿Qué casa abrir?"],
	"slots.slot": ["Slot %d", "Vaga %d", "Ranura %d"],
	"slots.empty": ["Empty", "Vazia", "Vacía"],
	"slots.brothers": ["%d brothers", "%d irmãos", "%d hermanos"],
	"slots.fallen": ["Fallen in the %s year", "Caiu no %s ano", "Caída en el año %s"],
	"slots.delete": ["Delete", "Apagar", "Borrar"],
	"slots.confirm_new": ["The house in slot %d will be closed for good. Begin again?", "A casa na vaga %d será fechada para sempre. Começar de novo?", "La casa en la ranura %d se cerrará para siempre. ¿Empezar de nuevo?"],
	"slots.confirm_delete": ["Delete the house in slot %d? Its annals will be lost for good.", "Apagar a casa da vaga %d? Seus anais se perderão para sempre.", "¿Borrar la casa de la ranura %d? Sus anales se perderán para siempre."],
	"slots.unreadable": ["That house could not be read. Its save may be from another version.", "Não foi possível ler essa casa. O arquivo pode ser de outra versão.", "No se pudo leer esa casa. Puede que su archivo sea de otra versión."],
	"settings.title": ["Settings", "Configurações", "Ajustes"],
	"settings.language": ["Language", "Idioma", "Idioma"],
	"settings.text_size": ["Text size", "Tamanho do texto", "Tamaño del texto"],
	"settings.hints": ["Tutorial hints", "Dicas do tutorial", "Consejos del tutorial"],
	"settings.confirm_close": ["Confirm before closing a house", "Confirmar antes de fechar uma casa", "Confirmar antes de cerrar una casa"],
	"settings.on": ["On", "Ligado", "Sí"],
	"settings.off": ["Off", "Desligado", "No"],
	"house.next_day": ["Next day", "Próximo dia", "Día siguiente"],
	"house.next_week": ["Next week", "Próxima semana", "Semana siguiente"],
	"house.until": ["Until event", "Até o evento", "Hasta el evento"],
	"house.menu": ["Menu", "Menu", "Menú"],
	"house.copy": ["Copy chronicle", "Copiar crônica", "Copiar crónica"],
	"house.save_text": ["Save chronicle as text file", "Salvar crônica como texto", "Guardar crónica como texto"],
	"house.settings": ["Settings", "Configurações", "Ajustes"],
	"house.to_menu": ["Back to the main menu", "Voltar ao menu principal", "Volver al menú principal"],
	"house.found_new": ["Found a new house", "Fundar uma nova casa", "Fundar una casa nueva"],
	"house.found_here": ["Found a new house here", "Fundar uma nova casa aqui", "Fundar una casa nueva aquí"],
	"house.fallen": ["The house has fallen. Its annals are complete.", "A casa caiu. Seus anais estão completos.", "La casa ha caído. Sus anales están completos."],
	"house.confirm_new": ["This house and its chronicle will be closed for good. Begin again?", "Esta casa e sua crônica serão fechadas para sempre. Começar de novo?", "Esta casa y su crónica se cerrarán para siempre. ¿Empezar de nuevo?"],
	"house.copied": ["The chronicle has been copied. Paste it anywhere.", "A crônica foi copiada. Cole onde quiser.", "La crónica se ha copiado. Pégala donde quieras."],
	"house.saved_to": ["Saved to:\n%s", "Salvo em:\n%s", "Guardado en:\n%s"],
	"house.not_saved": ["Could not save the file.", "Não foi possível salvar o arquivo.", "No se pudo guardar el archivo."],
	"house.next_text": ["The house is a text game. Use Next day, Next week or Until event to move the clock.", "A casa é um jogo de texto. Use Próximo dia, Próxima semana ou Até o evento para avançar o tempo.", "La casa es un juego de texto. Usa Día siguiente, Semana siguiente o Hasta el evento para avanzar el tiempo."],
}


## Registers one Translation per language. Called once from Settings at start.
static func register() -> void:
	for loc in LANGUAGES:
		var t := Translation.new()
		t.locale = loc
		var i := LANGUAGES.find(loc)
		for key in TABLE:
			t.add_message(key, str(TABLE[key][i]))
		TranslationServer.add_translation(t)
