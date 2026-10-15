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
	"tut.offer_title": ["The keeper's walk-through", "O passeio do guardião", "El recorrido del guardián"],
	"tut.offer_text": ["Would you like the keeper's walk-through? It takes about five minutes and can be left at any step.", "Quer o passeio guiado pelo guardião? Leva cerca de cinco minutos e pode ser deixado em qualquer passo.", "¿Quieres el recorrido del guardián? Dura unos cinco minutos y puedes dejarlo en cualquier paso."],
	"tut.begin": ["Begin the walk-through", "Começar o passeio", "Empezar el recorrido"],
	"tut.next": ["Next", "Próximo", "Siguiente"],
	"tut.finish": ["Finish", "Concluir", "Terminar"],
	"tut.skip_all": ["Skip all", "Pular tudo", "Saltar todo"],
	"tut.step_of": ["Step %d of %d", "Passo %d de %d", "Paso %d de %d"],
	"tut.replay": ["Replay the walk-through", "Refazer o passeio", "Repetir el recorrido"],
	"tut.house.title": ["The house", "A casa", "La casa"],
	"tut.house.text": ["The header shows the house, the date and any feast of the day, with the winter forecast below.", "O topo mostra a casa, a data e a festa do dia, com a previsão do inverno logo abaixo.", "El encabezado muestra la casa, la fecha y la fiesta del día, con el pronóstico del invierno debajo."],
	"tut.estate.title": ["The estate", "A propriedade", "La propiedad"],
	"tut.estate.text": ["Each brother has a job, chosen from the drop-down beside his name. Brothers at work build their skills.", "Cada irmão tem um trabalho, escolhido na lista ao lado do nome. Quem trabalha desenvolve suas habilidades.", "Cada hermano tiene un oficio, elegido en la lista junto a su nombre. Quien trabaja desarrolla sus habilidades."],
	"tut.time.title": ["Time", "O tempo", "El tiempo"],
	"tut.time.text": ["Next day, Next week and Until event move the clock. The forecast turns red when the winter stores are short.", "Próximo dia, Próxima semana e Até o evento movem o relógio. A previsão fica vermelha quando as reservas do inverno estão baixas.", "Día siguiente, Semana siguiente y Hasta el evento mueven el reloj. El pronóstico se pone rojo cuando las reservas del invierno escasean."],
	"tut.choice.title": ["Your first choice", "Sua primeira escolha", "Tu primera decisión"],
	"tut.choice.text": ["When something needs a decision, the event sheet opens. A choice in brackets is a check: 2d6 plus the brother's stat and skill against the difficulty.", "Quando algo exige uma decisão, abre-se a folha do evento. Uma escolha entre colchetes é um teste: 2d6 mais o atributo e a habilidade do irmão contra a dificuldade.", "Cuando algo requiere una decisión, se abre la hoja del evento. Una opción entre corchetes es una prueba: 2d6 más el atributo y la habilidad del hermano contra la dificultad."],
	"tut.road.title": ["The road", "A estrada", "El camino"],
	"tut.road.text": ["Tap a place on the map, choose brothers at home and send the party. Parties take weeks to walk there and back.", "Toque num lugar do mapa, escolha irmãos em casa e envie o grupo. A viagem leva semanas, ida e volta.", "Toca un lugar del mapa, elige hermanos en casa y envía el grupo. El viaje dura semanas, ida y vuelta."],
	"tut.paths.title": ["Skills and paths", "Habilidades e caminhos", "Habilidades y caminos"],
	"tut.paths.text": ["Skills grow by work and training. A brother's path shows as ? until an event reveals it.", "As habilidades crescem com o trabalho e o treino. O caminho de um irmão aparece como ? até um evento revelá-lo.", "Las habilidades crecen con el trabajo y el entrenamiento. El camino de un hermano aparece como ? hasta que un evento lo revele."],
	"tut.menu.title": ["The menu", "O menu", "El menú"],
	"tut.menu.text": ["The Menu button saves the chronicle as text, opens Settings and returns you to the main menu. You can replay this walk-through from Settings.", "O botão Menu salva a crônica em texto, abre as Configurações e leva ao menu principal. Você pode refazer este passeio em Configurações.", "El botón Menú guarda la crónica como texto, abre Ajustes y te lleva al menú principal. Puedes repetir este recorrido desde Ajustes."],
	"house.chronicle": ["Chronicle", "Crônica", "Crónica"],
	"house.estate": ["Estate", "Propriedade", "Hacienda"],
	"house.road": ["Road", "Estrada", "Camino"],
	"house.until_hint": ["Until event runs until a choice, a feast or a chronicle entry.", "Até o evento corre até uma escolha, uma festa ou um registro na crônica.", "Hasta el evento avanza hasta una decisión, una fiesta o una entrada en la crónica."],
	"house.feast": ["Today: %s", "Hoje: %s", "Hoy: %s"],
	"event.roll": ["Dice: 2d6 + %s + %s against %d", "Dados: 2d6 + %s + %s contra %d", "Dados: 2d6 + %s + %s contra %d"],
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
