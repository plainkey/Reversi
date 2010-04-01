package
{
	import com.christiancantrell.components.Alert;
	import com.christiancantrell.components.AlertEvent;
	import com.christiancantrell.components.Label;
	import com.christiancantrell.components.TextButton;
	import com.christiancantrell.data.HistoryEntry;
	import com.christiancantrell.utils.Layout;
	import com.christiancantrell.utils.Ruler;
	
	import flash.display.GradientType;
	import flash.display.InterpolationMethod;
	import flash.display.SpreadMethod;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.filters.BevelFilter;
	import flash.filters.BlurFilter;
	import flash.filters.DropShadowFilter;
	import flash.geom.Matrix;
	import flash.net.SharedObject;
	import flash.net.registerClassAlias;
	import flash.system.Capabilities;
	import flash.ui.Keyboard;
	
	public class Reversi extends Sprite
	{
		private const WHITE_COLOR:uint        = 0xffffff;
		private const WHITE_COLOR_NAME:String = "White";
		private const BLACK_COLOR:uint        = 0x000000;
		private const BLACK_COLOR_NAME:String = "Black";
		private const BOARD_COLORS:Array      = [0x666666, 0x333333];
		private const BOARD_LINES:uint        = 0x666666;
		private const BACKGROUND_COLOR:uint   = 0x666666;
		private const TITLE_COLOR:uint        = 0xffffff;
		private const TURN_GLOW_COLORS:Array  = [0xffffff, 0x000000];
		private const TITLE:String = "Reversi";
		private const WHITE:Boolean = true;
		private const BLACK:Boolean = false;
		private const PORTRAIT:String = "portrait";
		private const LANDSCAPE:String = "landscape";
		private const SINGLE_PLAYER_MODE:String = "singlePlayerMode";
		private const SINGLE_PLAYER_STRING:String = "Single Player Game";
		private const TWO_PLAYER_MODE:String = "twoPlayerMode";
		private const TWO_PLAYER_STRING:String = "Two Player Game";
		private const CANCEL_STRING:String = "Cancel";
		private const COMPUTER_COLOR_STRING:String = "Computer Plays ";
		private const SO_KEY:String = "com.christiancantrell.reversi";
		private const HISTORY_KEY:String = "history";
		private const PLAYER_MODE_KEY:String = "playerMode";
		private const COMPUTER_COLOR_KEY:String = "computerColor";
		private const CACHE_AS_BITMAP:Boolean = true;
		
		private var board:Sprite;
		private var stones:Array;
		private var turn:Boolean;
		private var pieces:Vector.<Sprite>;
		private var history:Array;
		private var historyIndex:int;
		private var title:Label;
		private var blackScoreLabel:Label, whiteScoreLabel:Label;
		private var backButton:TextButton, nextButton:TextButton;
		private var blackScore:uint;
		private var whiteScore:uint;
		private var turnFilter:BlurFilter;
		private var ppi:uint;
		private var stoneBevel:BevelFilter;
		private var boardShadow:DropShadowFilter;
		private var titleShadow:DropShadowFilter;
		private var playerMode:String;
		private var computerColor:Boolean;
		private var so:SharedObject;
		
		public function Reversi(ppi:int = -1)
		{
			super();
			registerClassAlias("com.christiancantrell.data.HistoryEntry", HistoryEntry);
			this.so = SharedObject.getLocal(SO_KEY);
			this.ppi = (ppi == -1) ? Capabilities.screenDPI : ppi;
			this.playerMode = SINGLE_PLAYER_MODE;
			this.computerColor = WHITE;
			if (!this.loadGame()) this.prepareGame();
			this.initUIComponents();
			this.addEventListener(Event.ADDED, onAddedToDisplayList);
		}
		
		private function loadGame():Boolean
		{
			var oldGame:Array = this.so.data[HISTORY_KEY] as Array;
			if (oldGame == null) return false;
			this.history = oldGame;
			var lastEntry:HistoryEntry;
			for (var i:uint = this.history.length; i >= 0; --i)
			{
				if (this.history[i] != null)
				{
					lastEntry = this.history[i] as HistoryEntry;
					this.historyIndex = i;
					break;
				}
			}
			this.turn = lastEntry.turn;
			this.stones = this.deepCopyStoneArray(lastEntry.board);
			this.playerMode = this.so.data[PLAYER_MODE_KEY];
			if (this.playerMode == SINGLE_PLAYER_MODE)
			{
				this.computerColor = this.so.data[COMPUTER_COLOR_KEY];
			}
			this.calculateScore();
			return true;
		}
		
		private function prepareGame():void
		{
			this.history = new Array(60);
			this.historyIndex = -1;
			this.turn = BLACK;  // Black always starts
			this.initStones();
			this.blackScore = 2;
			this.whiteScore = 2;
		}
		
		private function onAddedToDisplayList(e:Event):void
		{
			this.removeEventListener(Event.ADDED, onAddedToDisplayList);
			this.stage.addEventListener(Event.RESIZE, doLayout);
			this.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		}
		
		private function initUIComponents():void
		{
			var titleSize:uint = Ruler.mmToPixels(7, this.ppi);
			this.title = new Label(TITLE, "bold", TITLE_COLOR, "_sans", titleSize);
			this.titleShadow = new DropShadowFilter(0, 90, 0, 1, 10, 10, 1, 1, false, true);
			this.title.filters = [this.titleShadow];
			this.turnFilter = new BlurFilter(8, 8, 1);
			this.stoneBevel = new BevelFilter(1, 45);
			this.boardShadow = new DropShadowFilter(0, 90, 0, 1, 10, 10, 1, 1);
		}
		
		/**
		 * Lays out the application dynamically based on screen size and DPI.
		 * Public in case it needs to be called by the "host" code (which it
		 * usually won't).
		 **/
		public function doLayout(e:Event = null):void
		{
			// Remove any children that have already been added.
			while (this.numChildren > 0) this.removeChildAt(0);
			
			var stageWidth:uint = this.stage.stageWidth;
			var stageHeight:uint = this.stage.stageHeight;
			
			// Draw the background
			var bg:Sprite = new Sprite();
			bg.graphics.beginFill(BACKGROUND_COLOR);
			bg.graphics.drawRect(0, 0, stageWidth, stageHeight);
			bg.graphics.endFill();
			this.addChild(bg);
			
			// Figure out the size of the board
			var boardSize:uint = Math.min(stageWidth, stageHeight);
			
			// Figure out the placement of the board
			var boardX:uint, boardY:uint;
			if (boardSize == stageWidth)
			{
				boardX = 0;
				boardY = (stageHeight - stageWidth) / 2;
			}
			else
			{
				boardY = 0;
				boardX = (stageWidth - stageHeight) / 2;
			}

			// Create the board and place it
			this.board = new Sprite();
			this.board.x = boardX;
			this.board.y = boardY;
			
			// Draw the board's background
			var matrix:Matrix = new Matrix();
			matrix.createGradientBox(boardSize, boardSize, 0, 0, 0);
			this.board.graphics.beginGradientFill(GradientType.RADIAL, BOARD_COLORS, [1, 1], [0, 255], matrix, SpreadMethod.PAD, InterpolationMethod.RGB, 0);
			this.board.graphics.drawRect(0, 0, boardSize, boardSize);
			this.board.graphics.endFill();
			this.board.filters = [this.boardShadow];
			
			// Draw cells on board
			var lineSpace:Number = boardSize / 8;
			this.board.graphics.lineStyle(1, BOARD_LINES);
			var linePosition:uint = 0;
			for (var i:uint = 0; i <= 8; ++i)
			{
				linePosition = i * lineSpace;
				if (linePosition == boardSize) linePosition -= 1;
				// Veritcal
				this.board.graphics.moveTo(linePosition, 0);
				this.board.graphics.lineTo(linePosition, boardSize);
				// Horizontal
				this.board.graphics.moveTo(0, linePosition);
				this.board.graphics.lineTo(boardSize, linePosition);
			}

			this.addChild(this.board);
			this.placeStones();
			this.board.addEventListener(MouseEvent.CLICK, onBoardClicked);

			this.title.y = 24;
			var gutterWidth:uint, gutterHeight:uint, scoreSize:uint;
			var newGameButton:TextButton, buttonWidth:Number, buttonHeight:Number;
			if (this.getOrientation() == PORTRAIT) // Portrait
			{
				gutterHeight = (stageHeight - boardSize) / 2;
				gutterWidth = stageWidth;

				// Scores
				scoreSize = gutterHeight * .6;;
				this.blackScoreLabel = new Label(String(this.blackScore), "bold", BLACK_COLOR, "_sans", scoreSize);
				this.whiteScoreLabel = new Label(String(this.whiteScore), "bold", WHITE_COLOR, "_sans", scoreSize);

				Layout.centerHorizontally(this.title, this.stage);

				buttonWidth = stageWidth / 3;
				buttonHeight = Ruler.mmToPixels(10, this.ppi);
				
				this.backButton = new TextButton("BACK", true, buttonWidth, buttonHeight);
				this.backButton.addEventListener(MouseEvent.CLICK, this.onBack);
				this.backButton.x = 2;
				this.backButton.y = (stageHeight - this.backButton.height) - 1;
				this.addChild(this.backButton);
				
				newGameButton = new TextButton("NEW", true, buttonWidth - 6, buttonHeight);
				newGameButton.x = (gutterWidth / 2) - (this.backButton.width / 2) + 3;
				newGameButton.y = this.backButton.y;
				newGameButton.addEventListener(MouseEvent.CLICK, onNewGameButtonClicked);
				this.addChild(newGameButton);
				
				this.nextButton = new TextButton("NEXT", true, buttonWidth, buttonHeight);
				this.nextButton.addEventListener(MouseEvent.CLICK, this.onNext);
				this.nextButton.x = gutterWidth - this.nextButton.width - 2;
				this.nextButton.y = newGameButton.y;
				this.addChild(this.nextButton);
			}
			else // Landscape
			{
				gutterWidth = (stageWidth - boardSize) / 2;
				gutterHeight = stageHeight;

				// Scores
				scoreSize = gutterWidth * .75;
				this.blackScoreLabel = new Label(String(this.blackScore), "bold", BLACK_COLOR, "_sans", scoreSize);
				this.whiteScoreLabel = new Label(String(this.whiteScore), "bold", WHITE_COLOR, "_sans", scoreSize);
				
				this.title.x = ((boardX / 2) - (this.title.width / 2) - 4);

				buttonWidth = gutterWidth - 10;
				buttonHeight = Ruler.mmToPixels(10, this.ppi);

				newGameButton = new TextButton("NEW", false, buttonWidth, buttonHeight);
				newGameButton.x = (stageWidth - gutterWidth) + ((gutterWidth - newGameButton.width) / 2);
				newGameButton.y = 5;
				newGameButton.addEventListener(MouseEvent.CLICK, onNewGameButtonClicked);
				this.addChild(newGameButton);

				this.backButton = new TextButton("BACK", false, buttonWidth, buttonHeight);
				this.backButton.addEventListener(MouseEvent.CLICK, this.onBack);
				this.backButton.x = (gutterWidth - this.backButton.width) / 2;
				this.backButton.y = (stageHeight - this.backButton.height) - 5;
				this.addChild(this.backButton);
				
				this.nextButton = new TextButton("NEXT", false, buttonWidth, buttonHeight);
				this.nextButton.addEventListener(MouseEvent.CLICK, this.onNext);
				this.nextButton.x = newGameButton.x;
				this.nextButton.y = (stageHeight - this.nextButton.height) - 5;
				this.addChild(this.nextButton);
			}
			this.evaluateButtons();
			this.addChild(title);
			this.alignScores();
			this.addChild(this.blackScoreLabel);
			this.addChild(this.whiteScoreLabel);
			this.changeTurnIndicator();
		}
		
		private function alignScores():void
		{
			var gutterDimensions:Object = this.getGutterDimensions();
			if (this.getOrientation() == LANDSCAPE)
			{
				Layout.centerVertically(this.blackScoreLabel, this.stage);
				this.blackScoreLabel.x = (gutterDimensions.width / 2) - (this.blackScoreLabel.textWidth / 2);
				Layout.centerVertically(this.whiteScoreLabel, this.stage);
				this.whiteScoreLabel.x = this.stage.stageWidth - ((gutterDimensions.width / 2) + (this.whiteScoreLabel.textWidth / 2));
			}
			else
			{
				this.blackScoreLabel.y = ((gutterDimensions.height / 2) + (this.blackScoreLabel.textHeight / 2) + 7);
				this.blackScoreLabel.x = ((gutterDimensions.width / 4) - (this.blackScoreLabel.textWidth / 2) - 4);
				
				this.whiteScoreLabel.y = ((gutterDimensions.height / 2) + (this.whiteScoreLabel.textHeight / 2) + 7);
				this.whiteScoreLabel.x = ((gutterDimensions.width) - ((gutterDimensions.width / 4) + (this.blackScoreLabel.textWidth / 2)) + 4);
			}
		}
		
		private function getOrientation():String
		{
			return (this.stage.stageHeight > this.stage.stageWidth) ? PORTRAIT : LANDSCAPE;
		}

		private function getGutterDimensions():Object
		{
			var gutter:Object = new Object();
			var gutterWidth:uint, gutterHeight:uint;
			if (this.getOrientation() == PORTRAIT)
			{
				gutterWidth = this.stage.stageWidth;
				gutterHeight = (this.stage.stageHeight - this.board.width) / 2;
			}
			else
			{
				gutterWidth = (this.stage.stageWidth - this.board.width) / 2;
				gutterHeight = this.stage.stageHeight;
			}
			gutter.width = gutterWidth;
			gutter.height = gutterHeight;
			return gutter;
		}
		
		private function onKeyDown(e:KeyboardEvent):void
		{
			switch (e.keyCode)
			{
				case Keyboard.RIGHT:
					this.onNext();
					break;
				case Keyboard.LEFT:
					this.onBack();
					break;
			}
		}
		
		private function onBack(e:MouseEvent = null):void
		{
			if (this.historyIndex == 0) return;
			--this.historyIndex;
			var historyEntry:HistoryEntry = this.history[this.historyIndex] as HistoryEntry;
			this.stones = this.deepCopyStoneArray(historyEntry.board);
			this.turn = historyEntry.turn;
			this.placeStones();
			this.changeTurnIndicator();
			this.onTurnFinished(false, false);
		}
		
		private function onNext(e:MouseEvent = null):void
		{
			if (this.history[this.historyIndex+1] == null) return;
			++this.historyIndex;
			var historyEntry:HistoryEntry = this.history[this.historyIndex] as HistoryEntry;
			this.stones = this.deepCopyStoneArray(historyEntry.board);
			this.turn = historyEntry.turn;
			this.placeStones();
			this.changeTurnIndicator();
			this.onTurnFinished(false, false);
		}
		
		private function onNewGameButtonClicked(e:MouseEvent):void
		{
			var alert:Alert = new Alert(this.stage, this.ppi);
			alert.addEventListener(AlertEvent.ALERT_CLICKED, onNewGameConfirm);
			alert.show	("Confirm", "Do you want to start a new game?", [SINGLE_PLAYER_STRING, TWO_PLAYER_STRING, CANCEL_STRING]);
		}
		
		private function onNewGameConfirm(e:AlertEvent):void
		{
			var alert:Alert = e.target as Alert;
			alert.removeEventListener(AlertEvent.ALERT_CLICKED, onNewGameConfirm);
			if (e.label == CANCEL_STRING) return;
			this.deletePersistentData();
			if (e.label == TWO_PLAYER_STRING)
			{
				this.playerMode = TWO_PLAYER_MODE;
				this.prepareGame();
				this.placeStones();
				this.changeTurnIndicator();
				this.calculateScore();
				this.evaluateButtons();
			}
			else
			{
				var newAlert:Alert = new Alert(this.stage, this.ppi);
				newAlert.addEventListener(AlertEvent.ALERT_CLICKED, onComputerColorChosen);
				newAlert.show("Choose a Color",
							  "Choose a color for the computer. Remember, " + BLACK_COLOR_NAME + " always goes first.",
							  [COMPUTER_COLOR_STRING + WHITE_COLOR_NAME, COMPUTER_COLOR_STRING + BLACK_COLOR_NAME, CANCEL_STRING]);
			}
		}
		
		private function onComputerColorChosen(e:AlertEvent):void
		{
			if (e.label == CANCEL_STRING) return;
			this.playerMode = SINGLE_PLAYER_MODE;
			this.computerColor = (e.label == COMPUTER_COLOR_STRING + WHITE_COLOR_NAME) ? WHITE : BLACK;
			this.prepareGame();
			this.placeStones();
			this.changeTurnIndicator();
			this.calculateScore();
			this.evaluateButtons();
			if (this.computerColor == BLACK) this.onStartComputerMove();
		}
		
		private function initStones():void
		{
			this.stones = new Array(8);
			for (var i:uint = 0; i < 8; ++i)
			{
				this.stones[i] = new Array(8);
			}
			this.stones[3][3] = WHITE;
			this.stones[4][4] = WHITE;
			this.stones[4][3] = BLACK;
			this.stones[3][4] = BLACK;
			this.saveHistory();
		}
		
		private function saveHistory():void
		{
			++this.historyIndex;
			var historyEntry:HistoryEntry = new HistoryEntry();
			historyEntry.board = this.deepCopyStoneArray(this.stones);
			historyEntry.turn = this.turn;
			this.history[this.historyIndex] = historyEntry;
			for (var i:uint = this.historyIndex + 1; i < 64; ++i)
			{
				this.history[i] = null;
			}
			this.so.data[HISTORY_KEY] = this.history;
			this.so.data[PLAYER_MODE_KEY] = this.playerMode;
			this.so.data[COMPUTER_COLOR_KEY] = this.computerColor;
			this.so.flush();
		}
		
		private function deletePersistentData():void
		{
			this.so.data[HISTORY_KEY] = null;
			this.so.data[PLAYER_MODE_KEY] = null;
			this.so.data[COMPUTER_COLOR_KEY] = null;
			this.so.flush();
		}

		private function placeStones():void
		{
			this.pieces = new Vector.<Sprite>(64);
			while (this.board.numChildren > 0) this.board.removeChildAt(0);
			var cellSize:Number = (this.board.width / 8); 
			var stoneSize:Number = cellSize - 2;
			for (var x:uint = 0; x < 8; ++x)
			{
				for (var y:uint = 0; y < 8; ++y)
				{
					if (this.stones[x][y] == null) continue;
					this.placeStone(this.stones[x][y], x, y);
				}
			}
			if (CACHE_AS_BITMAP) this.board.cacheAsBitmap = true;
		}
		
		private function placeStone(color:Boolean, x:uint, y:uint):void
		{
			var cellSize:Number = (this.board.width / 8); 
			var stoneSize:Number = cellSize - 2;
			this.removePieceFromBoard(x, y);
			var stone:Sprite = new Sprite();
			this.pieces[this.coordinatesToIndex(x, y)] = stone;
			stone.mouseEnabled = false;
			stone.graphics.beginFill((color == WHITE) ? WHITE_COLOR : BLACK_COLOR);
			stone.graphics.drawCircle(stoneSize/2, stoneSize/2, stoneSize/2);
			stone.graphics.endFill();
			stone.filters = [this.stoneBevel];
			if (CACHE_AS_BITMAP) stone.cacheAsBitmap = true;
			stone.x = (x * cellSize) + 1;
			stone.y = (y * cellSize) + 1;
			this.board.addChild(stone);
		}
		
		private function removePieceFromBoard(x:uint, y:uint):void
		{
			var index:uint = this.coordinatesToIndex(x, y);
			if (this.pieces[index] != null)
			{
				this.board.removeChild(Sprite(this.pieces[index]));
			}
		}
		
		private function coordinatesToIndex(x:uint, y:uint):uint
		{
			return (y * 8) + x;
		}
		
		private function onBoardClicked(e:MouseEvent):void
		{
			if (this.playerMode == SINGLE_PLAYER_MODE && this.turn == this.computerColor) return;
			var scaleFactor:uint = this.board.width / 8;
			var x:uint = e.localX / scaleFactor;
			var y:uint = e.localY / scaleFactor;
			this.makeMove(x, y);
			if (this.playerMode == SINGLE_PLAYER_MODE && this.turn == this.computerColor)
			{
				this.onStartComputerMove();
			}
		}
		
		private function makeMove(x:uint, y:uint):void
		{
			if (this.stones[x][y] != null) return;
			if (this.findCaptures(this.turn, x, y, true) == 0) return;
			this.placeStone(this.turn, x, y);
			this.stones[x][y] = this.turn;
			this.onTurnFinished(true, true);
		}
		
		private function deepCopyStoneArray(stoneArray:Array):Array
		{
			var newStones:Array = new Array(8);
			for (var x:uint = 0; x < 8; ++x)
			{
				newStones[x] = new Array(8);
				for (var y:uint = 0; y < 8; ++y)
				{
					if (stoneArray[x][y] != null) newStones[x][y] = stoneArray[x][y];
				}
			}
			return newStones;
		}
		
		private function findCaptures(turn:Boolean, x:uint, y:uint, turnStones:Boolean, stones:Array = null):uint
		{
			stones = (stones == null) ? this.stones : stones;
			if (stones[x][y] != null) return 0;
			var topLeft:uint     = this.walkPath(turn, x, y, -1, -1, turnStones, stones); // top left
			var top:uint         = this.walkPath(turn, x, y,  0, -1, turnStones, stones); // top
			var topRight:uint    = this.walkPath(turn, x, y,  1, -1, turnStones, stones); // top right
			var right:uint       = this.walkPath(turn, x, y,  1,  0, turnStones, stones); // right
			var bottomRight:uint = this.walkPath(turn, x, y,  1,  1, turnStones, stones); // bottom right
			var bottom:uint      = this.walkPath(turn, x, y,  0,  1, turnStones, stones); // bottom
			var bottomLeft:uint  = this.walkPath(turn, x, y, -1, +1, turnStones, stones); // bottom left
			var left:uint        = this.walkPath(turn, x, y, -1,  0, turnStones, stones); // left
			return (topLeft + top + topRight + right + bottomRight + bottom + bottomLeft + left);
		}
		
		private function walkPath(turn:Boolean, x:uint, y:uint, xFactor:int, yFactor:int, turnStones:Boolean, stones:Array):uint
		{
			// Are we in bounds?
			if (x + xFactor > 7 || x + xFactor < 0 || y + yFactor > 7 || y + yFactor < 0)
			{
				return 0;
			}

			// Is the next squre empty?
			if (stones[x + xFactor][y + yFactor] == null)
			{
				return 0;
			}
			
			var nextStone:Boolean = stones[x + xFactor][y + yFactor];

			// Is the next stone the wrong color?
			if (nextStone != !turn)
			{
				return 0;
			}
			
			// Find the next piece of the same color
			var tmpX:int = x, tmpY:int = y;
			var stoneCount:uint = 0;
			while (true)
			{
				++stoneCount;
				tmpX = tmpX + xFactor;
				tmpY = tmpY + yFactor;
				if (tmpX < 0 || tmpY < 0 || tmpX > 7 || tmpY > 7 || stones[tmpX][tmpY] == null) // Not enclosed
				{
					return 0;
				}
				nextStone = this.stones[tmpX][tmpY];
				if (nextStone == turn) // Capture!
				{
					if (turnStones) this.turnStones(turn, x, y, tmpX, tmpY, xFactor, yFactor, stones);
					return stoneCount - 1;
				}
			}
			return 0;
		}
		
		private function turnStones(turn:Boolean, fromX:uint, fromY:uint, toX:uint, toY:uint, xFactor:uint, yFactor:uint, stones:Array):void
		{
			var nextX:uint = fromX, nextY:uint = fromY;
			while (true)
			{
				nextX = nextX + xFactor;
				nextY = nextY + yFactor;
				stones[nextX][nextY] = turn;
				if (stones == this.stones) this.placeStone(turn, nextX, nextY);
				if (nextX == toX && nextY == toY) return;
			}
		}
		
		private function onTurnFinished(changeTurn:Boolean, saveHistory:Boolean):void
		{
			if (changeTurn) this.changeTurn();
			this.calculateScore();
			if (this.isNextMovePossible(this.turn))
			{
				this.finishTurn(saveHistory);
				return;
			}

			if ((this.blackScore + this.whiteScore) == 64) // All stones played. Game is over.
			{
				var allStonesPlayedAlert:Alert = new Alert(this.stage, this.ppi);
				if (this.blackScore == this.whiteScore) // Tie game
				{
					allStonesPlayedAlert.show("Tie Game!", "Good job! You both finished with the exact same number of stones.");
					this.finishTurn(saveHistory);
					return;
				}
				var winner:String = (this.blackScore > this.whiteScore) ? BLACK_COLOR_NAME : WHITE_COLOR_NAME;
				allStonesPlayedAlert.show(winner + " Wins!", "All stones have been played, so the game is over. Well done, " + winner + "!");
				this.finishTurn(saveHistory);
				return;
			}
			
			if (this.blackScore == 0 || this.whiteScore == 0) // All stones captured. Game over.
			{
				var allStonesCapturedAlert:Alert = new Alert(this.stage, this.ppi);
				var zeroPlayer:String = (this.blackScore == 0) ? BLACK_COLOR_NAME : WHITE_COLOR_NAME;
				var nonZeroPlayer:String = (this.blackScore != 0) ? BLACK_COLOR_NAME : WHITE_COLOR_NAME;
				allStonesCapturedAlert.show(nonZeroPlayer + " Wins!", nonZeroPlayer + " has captured all of " + zeroPlayer + "'s stones. Well done, " + nonZeroPlayer + "!");
				this.finishTurn(saveHistory);
				return;
			}
			
			if (!this.isNextMovePossible(!this.turn)) // Neither player can make a move. Unusual, but possible. Game is over.
			{
				var noMoreMovesAlert:Alert = new Alert(this.stage, this.ppi);
				if (this.blackScore == this.whiteScore) // Tie game
				{
					noMoreMovesAlert.show("Tie Game!", "Neither player can make a move, and you both have the exact same number of stones. Good game!");
					this.finishTurn(saveHistory);
					return;
				}
				var defaultWinner:String = (this.blackScore > this.whiteScore) ? BLACK_COLOR_NAME : WHITE_COLOR_NAME;
				noMoreMovesAlert.show(defaultWinner + " Wins!", "Neither player can make a move, therefore the game is over and " + defaultWinner + " wins!");
				this.finishTurn(saveHistory);
				return;
			}

			// Game isn't over, but opponent can't place a stone.
			if (changeTurn) this.changeTurn();
			var noNextMoveAlert:Alert = new Alert(this.stage, this.ppi);
			var side:String = (this.turn == WHITE) ? BLACK_COLOR_NAME : WHITE_COLOR_NAME;
			var otherSide:String = (this.turn != WHITE) ? BLACK_COLOR_NAME : WHITE_COLOR_NAME;
			noNextMoveAlert.addEventListener(AlertEvent.ALERT_CLICKED, onNoNextMovePossible);
			noNextMoveAlert.show("No Move Available", side + " has no possible moves, and therefore must pass. It's still " + otherSide + "'s turn.");
			this.finishTurn(saveHistory);
		}

		private function finishTurn(saveHistory:Boolean):void
		{
			if (saveHistory) this.saveHistory();
			this.evaluateButtons();
		}
		
		private function onNoNextMovePossible(e:AlertEvent):void
		{
			var alert:Alert = e.target as Alert;
			alert.removeEventListener(AlertEvent.ALERT_CLICKED, onNoNextMovePossible);
			if (this.playerMode == SINGLE_PLAYER_MODE && this.turn == computerColor)
			{
				this.onStartComputerMove();
			}
		}
		
		private function isNextMovePossible(player:Boolean):Boolean
		{
			for (var x:uint = 0; x < 8; ++x)
			{
				for (var y:uint = 0; y < 8; ++y)
				{
					if (this.stones[x][y] != null) continue;
					if (this.findCaptures(player, x, y, false) > 0) return true;
				}
			}
			return false;
		}
		
		private function changeTurn():void
		{
			this.turn = !this.turn;
			this.changeTurnIndicator();
		}
		
		private function changeTurnIndicator():void
		{
			if (this.turn == WHITE)
			{
				this.whiteScoreLabel.filters = null;
				this.blackScoreLabel.filters = [this.turnFilter];
			}
			else
			{
				this.blackScoreLabel.filters = null;
				this.whiteScoreLabel.filters = [this.turnFilter];
			}
		}
		
		private function evaluateButtons():void
		{
			this.backButton.enabled = (this.historyIndex == 0) ? false : true;
			this.nextButton.enabled = (this.history[this.historyIndex+1] == null) ? false : true;
		}
		
		private function calculateScore():void
		{
			var black:uint = 0;
			var white:uint = 0;
			for (var x:uint = 0; x < this.stones.length; ++x)
			{
				for (var y:uint = 0; y < this.stones[x].length; ++y)
				{
					if (this.stones[x][y] == null)
					{
						continue;
					}
					else if (this.stones[x][y] == WHITE)
					{
						++white;
					}
					else
					{
						++black;
					}
				}
			}
			this.blackScore = black;
			this.whiteScore = white;
			if (this.whiteScoreLabel!= null && this.blackScoreLabel != null)
			{
				this.whiteScoreLabel.update(String(this.whiteScore));
				this.blackScoreLabel.update(String(this.blackScore));
				this.alignScores();
			}
		}
		
		////  Simple triage-based AI. Opt for the best moves first, and the worst moves last. ////
		
		private const TOP_LEFT_CORNER:Array     = [0,0];
		private const TOP_RIGHT_CORNER:Array    = [7,0];
		private const BOTTOM_RIGHT_CORNER:Array = [7,7];
		private const BOTTOM_LEFT_CORNER:Array  = [0,7];
		
		private const TOP_LEFT_X:Array     = [1,1];
		private const TOP_RIGHT_X:Array    = [6,1];
		private const BOTTOM_RIGHT_X:Array = [6,6];
		private const BOTTOM_LEFT_X:Array  = [1,6];

		private const TOP_TOP_LEFT:Array        = [1,0];
		private const TOP_BOTTOM_LEFT:Array     = [0,1];
		private const TOP_TOP_RIGHT:Array       = [6,0];
		private const TOP_BOTTOM_RIGHT:Array    = [7,1];
		private const BOTTOM_TOP_RIGHT:Array    = [7,6];
		private const BOTTOM_BOTTOM_RIGHT:Array = [6,7];
		private const BOTTOM_TOP_LEFT:Array     = [0,6];
		private const BOTTOM_BOTTOM_LEFT:Array  = [1,7];
		
		private function onStartComputerMove():void
		{
			// Try to capture a corner...
			if (this.findCaptures(this.computerColor, TOP_LEFT_CORNER[0],     TOP_LEFT_CORNER[1],     false) > 0) {this.onFinishComputerMove(TOP_LEFT_CORNER[0],     TOP_LEFT_CORNER[1]);     return;}
			if (this.findCaptures(this.computerColor, TOP_RIGHT_CORNER[0],    TOP_RIGHT_CORNER[1],    false) > 0) {this.onFinishComputerMove(TOP_RIGHT_CORNER[0],    TOP_RIGHT_CORNER[1]);    return;}
			if (this.findCaptures(this.computerColor, BOTTOM_RIGHT_CORNER[0], BOTTOM_RIGHT_CORNER[1], false) > 0) {this.onFinishComputerMove(BOTTOM_RIGHT_CORNER[0], BOTTOM_RIGHT_CORNER[1]); return;}
			if (this.findCaptures(this.computerColor, BOTTOM_LEFT_CORNER[0],  BOTTOM_LEFT_CORNER[1],  false) > 0) {this.onFinishComputerMove(BOTTOM_LEFT_CORNER[0],  BOTTOM_LEFT_CORNER[1]);  return;}

			// If you already own a corner, try to build off it...
			if (this.stones[TOP_LEFT_CORNER[0]][TOP_LEFT_CORNER[1]] == this.computerColor)
			{
				if (this.findAdjacentMove(TOP_LEFT_CORNER[0], TOP_LEFT_CORNER[1], 1, 0, 6)) return;
				if (this.findAdjacentMove(TOP_LEFT_CORNER[0], TOP_LEFT_CORNER[1], 0, 1, 6)) return;
			}
			if (this.stones[TOP_RIGHT_CORNER[0]][TOP_RIGHT_CORNER[1]] == this.computerColor)
			{
				if (this.findAdjacentMove(TOP_RIGHT_CORNER[0], TOP_RIGHT_CORNER[1], -1, 0, 6)) return;
				if (this.findAdjacentMove(TOP_RIGHT_CORNER[0], TOP_RIGHT_CORNER[1], 0, 1, 6)) return;
			}
			if (this.stones[BOTTOM_RIGHT_CORNER[0]][BOTTOM_RIGHT_CORNER[1]] == this.computerColor)
			{
				if (this.findAdjacentMove(BOTTOM_RIGHT_CORNER[0], BOTTOM_RIGHT_CORNER[1], -1, 0, 6)) return;
				if (this.findAdjacentMove(BOTTOM_RIGHT_CORNER[0], BOTTOM_RIGHT_CORNER[1], 0, -1, 6)) return;
			}
			if (this.stones[BOTTOM_LEFT_CORNER[0]][BOTTOM_LEFT_CORNER[1]] == this.computerColor)
			{
				if (this.findAdjacentMove(BOTTOM_LEFT_CORNER[0], BOTTOM_LEFT_CORNER[1], 1, 0, 6)) return;
				if (this.findAdjacentMove(BOTTOM_LEFT_CORNER[0], BOTTOM_LEFT_CORNER[1], 0, -1, 6)) return;
			}
			
			// Try to capture a side piece, but nothing adjacent to a corner
			if (this.findAdjacentMove(TOP_TOP_LEFT[0],        TOP_TOP_LEFT[1],         1,  0, 4)) return;
			if (this.findAdjacentMove(TOP_BOTTOM_RIGHT[0],    TOP_BOTTOM_RIGHT[1],     0,  1, 4)) return;
			if (this.findAdjacentMove(BOTTOM_BOTTOM_RIGHT[0], BOTTOM_BOTTOM_RIGHT[1], -1,  0, 4)) return;
			if (this.findAdjacentMove(BOTTOM_TOP_LEFT[0],     BOTTOM_TOP_LEFT[1],      0, -1, 4)) return;

			// Find the move that captures the most stones (excluding X-squares and squares close to corners)...
			var captureCounts:Array = new Array();
			for (var x:uint = 0; x < 7; ++x)
			{
				for (var y:uint = 0; y < 7; ++y)
				{
					if (this.stones[x][y] != null) continue;
					if ((x == TOP_LEFT_X[0]          && y == TOP_LEFT_X[1]) ||
						(x == TOP_RIGHT_X[0]         && y == TOP_RIGHT_X[1]) ||
						(x == BOTTOM_LEFT_X[0]       && y == BOTTOM_LEFT_X[1]) ||
						(x == BOTTOM_RIGHT_X[0]      && y == BOTTOM_RIGHT_X[1]) ||
						(x == TOP_TOP_LEFT[0]        && y == TOP_TOP_LEFT[1]) ||
						(x == TOP_BOTTOM_LEFT[0]     && y == TOP_BOTTOM_LEFT[1]) ||
						(x == TOP_TOP_RIGHT[0]       && y == TOP_TOP_RIGHT[1]) ||
						(x == TOP_BOTTOM_RIGHT[0]    && y == TOP_BOTTOM_RIGHT[1]) ||
						(x == BOTTOM_TOP_RIGHT[0]    && y == BOTTOM_TOP_RIGHT[1]) ||
						(x == BOTTOM_BOTTOM_RIGHT[0] && y == BOTTOM_BOTTOM_RIGHT[1]) ||
						(x == BOTTOM_TOP_LEFT[0]     && y == BOTTOM_TOP_LEFT[1]) ||
						(x == BOTTOM_BOTTOM_LEFT[0]  && y == BOTTOM_BOTTOM_LEFT[1]))
					{
						continue;
					}
					var captureCount:uint = this.findCaptures(this.computerColor, x, y, false);
					if (captureCount == 0) continue;
					var captureData:Object = new Object();
					captureData.stones = captureCount;
					captureData.x = x;
					captureData.y = y;
					captureCounts.push(captureData);
				}
			}

			if (captureCounts.length > 0)
			{
				captureCounts.sortOn("stones", Array.NUMERIC, Array.DESCENDING);
				var bestMove:Object = captureCounts.pop();
				if (bestMove.stones > 0)
				{
					this.onFinishComputerMove(bestMove.x, bestMove.y);
					return;
				}
			}

			// No choice but to move adjacent to a corner.
			if (this.findCaptures(this.computerColor, TOP_TOP_LEFT[0],        TOP_TOP_LEFT[1],        false)) {this.onFinishComputerMove(TOP_TOP_LEFT[0],        TOP_TOP_LEFT[1]); return;}
			if (this.findCaptures(this.computerColor, TOP_BOTTOM_LEFT[0],     TOP_BOTTOM_LEFT[1],     false)) {this.onFinishComputerMove(TOP_BOTTOM_LEFT[0],     TOP_BOTTOM_LEFT[1]); return;}
			if (this.findCaptures(this.computerColor, TOP_TOP_RIGHT[0],       TOP_TOP_RIGHT[1],       false)) {this.onFinishComputerMove(TOP_TOP_RIGHT[0],       TOP_TOP_RIGHT[1]); return;}
			if (this.findCaptures(this.computerColor, TOP_BOTTOM_RIGHT[0],    TOP_BOTTOM_RIGHT[1],    false)) {this.onFinishComputerMove(TOP_BOTTOM_RIGHT[0],    TOP_BOTTOM_RIGHT[1]); return;}
			if (this.findCaptures(this.computerColor, BOTTOM_TOP_RIGHT[0],    BOTTOM_TOP_RIGHT[1],    false)) {this.onFinishComputerMove(BOTTOM_TOP_RIGHT[0],    BOTTOM_TOP_RIGHT[1]); return;}
			if (this.findCaptures(this.computerColor, BOTTOM_BOTTOM_RIGHT[0], BOTTOM_BOTTOM_RIGHT[1], false)) {this.onFinishComputerMove(BOTTOM_BOTTOM_RIGHT[0], BOTTOM_BOTTOM_RIGHT[1]); return;}
			if (this.findCaptures(this.computerColor, BOTTOM_TOP_LEFT[0],     BOTTOM_TOP_LEFT[1],     false)) {this.onFinishComputerMove(BOTTOM_TOP_LEFT[0],     BOTTOM_TOP_LEFT[1]); return;}
			if (this.findCaptures(this.computerColor, BOTTOM_BOTTOM_LEFT[0],  BOTTOM_BOTTOM_LEFT[1],  false)) {this.onFinishComputerMove(BOTTOM_BOTTOM_LEFT[0],  BOTTOM_BOTTOM_LEFT[1]); return;}
			
			// No choice but to move in one of the x-squares. Worst possible move.
			if (this.findCaptures(this.computerColor, TOP_LEFT_X[0],     TOP_LEFT_X[1],     false)) {this.onFinishComputerMove(TOP_LEFT_X[0],     TOP_LEFT_X[1]); return;}
			if (this.findCaptures(this.computerColor, TOP_RIGHT_X[0],    TOP_RIGHT_X[1],    false)) {this.onFinishComputerMove(TOP_RIGHT_X[0],    TOP_RIGHT_X[1]); return;}
			if (this.findCaptures(this.computerColor, BOTTOM_LEFT_X[0],  BOTTOM_LEFT_X[1],  false)) {this.onFinishComputerMove(BOTTOM_LEFT_X[0],  BOTTOM_LEFT_X[1]); return;}
			if (this.findCaptures(this.computerColor, BOTTOM_RIGHT_X[0], BOTTOM_RIGHT_X[1], false)) {this.onFinishComputerMove(BOTTOM_RIGHT_X[0], BOTTOM_RIGHT_X[1]); return;}
		}
		
		private function findAdjacentMove(x:uint, y:uint, xFactor:int, yFactor:int, depth:uint):Boolean
		{
			var testX:uint = x, testY:uint = y;
			for (var i:uint = 0; i < depth; ++i)
			{
				testX += xFactor;
				testY += yFactor;
				if (this.stones[testX][testY] == null)
				{
					if (this.findCaptures(this.computerColor, testX, testY, false) > 0)
					{
						this.onFinishComputerMove(testX, testY);
						return true;
					}
				}
			}
			return false;
		}
		
		private function onFinishComputerMove(x:uint, y:uint):void
		{
			this.makeMove(x, y);
		}
	}
}