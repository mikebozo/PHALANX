package com.isartdigital.utils.game;

import com.isartdigital.utils.system.DeviceCapabilities;
import haxe.Json;
import pixi.core.display.Container;
import pixi.core.graphics.Graphics;
import pixi.core.math.Point;
import pixi.core.math.shapes.Circle;
import pixi.core.math.shapes.Ellipse;
import pixi.core.math.shapes.Rectangle;
import pixi.core.textures.Texture;
import pixi.extras.MovieClip;

/**
 * Classe de base des objets interactifs ayant plusieurs états graphiques
 * Gère la représentation graphique (anim) et les conteneurs utiles au gamePlay (box) qui peuvent être de simples boites de collision ou beaucoup plus
 * suivant l'implémentation faite par le développeur dans les classes filles
 * @author Mathieu ANTHOINE
 * @version 0.11.0
 */
class StateGraphic extends GameObject
{
	 
	/**
	 * anim de l'état courant
	 */
	private var anim:MovieClip;
	
	
	
	/**
	 * box de l'état courant
	 */
	private var box:Container;
	
	/**
	 * suffixe du nom d'export des symboles Animés
	 */
	private var ANIM_SUFFIX (default,null):String = "";
	
	/**
	 * suffixe du nom d'export des symboles Box
	 */
	private var BOX_SUFFIX (default,null):String = "box";	
	
	/**
	 * longueur de la numérotation des textures
	 */
	public static var textureDigits (default, set) :UInt = 4;
	
	private static function set_textureDigits (pDigits:UInt) : UInt {
		digits = "";
		for (i in 0...pDigits) digits += "0";
		return textureDigits = pDigits;	
	}

	/**
	 * nombre de zéro a ajouter pour construire un nom de frame
	 */
	private static var digits:String;	

	/**
	 * définition des textures (nombre d'images)
	 */
	private static var texturesDefinition:Map<String,Int>;
	
	/**
	 * définition des ancres des textures
	 */
	private static var texturesAnchor:Map<String,Point>;	
	
	/**
	 * cache des textures de tous les StateGraphic
	 */
	private static var texturesCache:Map<String,Array<Texture>>;	
	
	/**
	 * etat par défaut
	 */
	private var DEFAULT_STATE (default, null): String = "";
	
	/**
	 * Nom de l'asset (sert à identifier les textures à utiliser)
	 * Prend le nom de la classe Fille par défaut
	 */
	private var assetName:String;
	
	/**
	 * état en cours
	 */
	private var state:String;
	
	/**
	 * Type de box de collision
	 * Si boxType est égal à BoxType.NONE, aucune collision ne se fait, il n'est pas nécessaire d'avoir une boite de collision définie
	 * Si boxType est égal à BoxType.SIMPLE, seul un symbole sert de Box pour tous les états, son nom d'export etant assetName+"_"+BOX_SUFFIX
	 * Si boxType est égal à BoxType.MULTIPLE, chaque state correspond à une boite de collision, chaque state va cherche la boite assetName+"_"+ANIM_SUFFIX+"_"+BOX_SUFFIX
	 * Si boxType est égal à BoxType.SELF, hitBox retourne le MovieClip anim
	 */
	private var boxType:BoxType=BoxType.NONE;
	
	/**
	 * niveau d'alpha des anim
	 */
	public static var animAlpha:Float = 1;
	
	/**
	 * niveau d'alpha des Boxes
	 */
	public static var boxAlpha:Float = 0;
	
	/**
	 * cache des boxes de tous les StateGraphic
	 */
	private static var boxesCache:Map<String,Map<String,Dynamic>>;
	
	/**
	 * l'anim est-elle terminée ?
	 */
	public var isAnimEnd (default, null):Bool;
	
	private function setAnimEnd ():Void {
		isAnimEnd = true;
	}
	
	public function new() 
	{
		super();
	}
	
	/**
	 * défini l'état courant du StateGraphic
	 * @param	pState nom de l'état (run, walk...)
	 * @param	pLoop l'anim boucle (isAnimEnd sera toujours false) ou pas
	 * @param	pAutoPlay lance l'anim automatiquement
	 * @param	pStart lance l'anim à cette frame
	 */
	private function setState (pState:String, ?pLoop:Bool = false, ?pAutoPlay:Bool=true, ?pStart:UInt = 0): Void {
		
		if (state == pState) return;
		
		if (assetName == null) assetName = Type.getClassName(Type.getClass(this)).split(".").pop();
		state = pState;
		
		if (anim == null) {
			anim = new MovieClip (getTextures(state));
			if (boxType == BoxType.SELF) {
				if (box !=null) removeChild(box);
				box = null;
			}
			anim.scale.set(1 /DeviceCapabilities.textureRatio , 1 / DeviceCapabilities.textureRatio);
			if (animAlpha < 1) anim.alpha = animAlpha;
			addChild(anim);
		} else anim.textures = getTextures(state);

		isAnimEnd = false;
		anim.onComplete = setAnimEnd;
		anim.anchor = getAnchor(state);
		anim.loop = pLoop;
		if (anim.totalFrames > 1) anim.gotoAndStop(pStart);
		else anim.gotoAndStop(0);
		if (pAutoPlay) anim.play();
		
		if (box == null) {
			if (boxType == BoxType.SELF) {
				box = anim;
				return;
			} else {
				box = new Container();
				if (boxType != BoxType.NONE) createBox();
			}
			addChild(box);
		} else if (boxType == BoxType.MULTIPLE) {
			removeChild(box);
			box = new Container();
			createBox();
			addChild(box);
		}
		
	}
	
	/**
	 * crée la ou les box de collision de l'état
	 */
	private function createBox ():Void {
		var lBoxes:Map<String,Dynamic> = getBox((boxType == BoxType.MULTIPLE ? state+ "_": "" )  + BOX_SUFFIX);
		var lChild:Graphics;
		
		for (lBox in lBoxes.keys()) {
			lChild = new Graphics();
			lChild.beginFill(0xFF2222);
			if (Std.is(lBoxes[lBox], Rectangle)) {
				lChild.drawRect(lBoxes[lBox].x, lBoxes[lBox].y, lBoxes[lBox].width, lBoxes[lBox].height);
			}
			else if (Std.is(lBoxes[lBox], Ellipse)) {
				lChild.drawEllipse(lBoxes[lBox].x, lBoxes[lBox].y, lBoxes[lBox].width, lBoxes[lBox].height);
			}
			else if (Std.is(lBoxes[lBox], Circle)) {
				lChild.drawCircle(lBoxes[lBox].x,lBoxes[lBox].y,lBoxes[lBox].radius);
			}
			else if (Std.is(lBoxes[lBox], Point)) {
				lChild.drawCircle(0, 0, 10);
			}
			lChild.endFill();
			
			lChild.name = lBox;
			if (Std.is(lBoxes[lBox], Point)) lChild.position.set(lBoxes[lBox].x, lBoxes[lBox].y);
			else lChild.hitArea = lBoxes[lBox];
			 
			box.addChild(lChild);
		}
		if (boxAlpha == 0) box.renderable = false;
		else box.alpha= boxAlpha;
	}
	
	/**
	 * Analyse et crée les définitions de textures
	 * @param	pJson objet contenant la description des assets
	 */
	static public function addTextures (pJson:Json): Void {
		
		var lFrames:Dynamic = Reflect.field(pJson, "frames");
		
		if (texturesDefinition == null) texturesDefinition = new Map<String,Int>();
		if (texturesAnchor == null) texturesAnchor = new Map<String,Point>();
		if (texturesCache == null) texturesCache = new Map<String,Array<Texture>>();		
		if (digits == null) textureDigits = textureDigits;
		
		var lID:String;
		var lNum:Int;
		
		for (lName in Reflect.fields(lFrames)) {
			
			lID = lName.split(".")[0];
			lNum = Std.parseInt(lID.substr(-1*textureDigits));
			if (lNum != null) lID = lID.substr(0, lID.length - textureDigits);
			
			if (texturesDefinition[lID] == null) texturesDefinition[lID] = lNum == null ? 1 : lNum;
			else if (lNum > texturesDefinition[lID]) texturesDefinition[lID] = lNum;
			
			if (texturesAnchor[lID] == null) texturesAnchor[lID] = Reflect.field(lFrames, lName).pivot;
		}
		
	}	

	/**
	 * Vide le cache de textures correspondant à la description passée en paramètres
	 * @param	pJson objet contenant la description des assets
	 */
	static public function clearTextures (pJson:Json): Void {
		
		var lFrames:Dynamic = Reflect.field(pJson, "frames");
		
		if (texturesDefinition == null) return;
		
		var lID:String;
		var lNum:Int;
		
		for (lID in Reflect.fields(lFrames)) {
			
			lID = lID.split(".")[0];
			lNum = Std.parseInt(lID.substr(-1*textureDigits));
			if (lNum != null) lID = lID.substr(0, lID.length - textureDigits);
			
			texturesDefinition[lID] = null;
			texturesAnchor[lID] = null;
			texturesCache[lID] = null;
		}
	}	

	/**
	 * Cherche dans le cache général de textures le tableau de textures correspondant au state et le retourne.
	 * Si le tableau de texture n'éxiste pas, il le crée et le stocke dans le cache
	 * @param	pState State de l'instance
	 * @return	le tableau de texture correspondant au state de l'instance
	 */
	private function getTextures(pState:String):Array<Texture> {
		
		var lID:String;
		
		if (pState == DEFAULT_STATE) lID = assetName+ANIM_SUFFIX;
		else lID = assetName+"_" + pState+ANIM_SUFFIX;
		
		if (texturesCache[lID] == null) {
			var lFrames:UInt = texturesDefinition[lID];
			if (lFrames == 1) texturesCache[lID] =[Texture.fromFrame(lID+".png")];
			else {
				texturesCache[lID] = new Array<Texture>();
				for (i in 1...lFrames+1) texturesCache[lID].push(Texture.fromFrame(lID+(digits + i).substr(-1*textureDigits) + ".png"));
			}
			
		}
		
		return texturesCache[lID];
	}
	
	/**
	 * retourne l'ancre suivant le state
	 * @param	pState State de l'instance
	 * @return	l'ancre
	 */
	private function getAnchor (pState:String):Point {
		var lID:String;
		
		if (pState == DEFAULT_STATE) lID = assetName+ANIM_SUFFIX;
		else lID = assetName+"_" + pState+ANIM_SUFFIX;
		
		return texturesAnchor[lID];
	}
	
	/**
	 * Créer toutes les Boxes
	 * @param	pJson Nom du fichier contenant la description des boxes
	 */
	static public function addBoxes (pJson:Json): Void {
		
		if (boxesCache == null) boxesCache = new Map<String,Map<String,Dynamic>>();
		
		var lItem;
		var lObj;
		
		for (lName in Reflect.fields(pJson)) {
			lItem = Reflect.field(pJson, lName);
			
			boxesCache[lName] = new Map<String,Dynamic>();			
			
			for (lObjName in Reflect.fields(lItem)) {
				lObj = Reflect.field(lItem, lObjName);
				
				if (lObj.type == "Rectangle") boxesCache[lName][lObjName] = new Rectangle(lObj.x, lObj.y, lObj.width, lObj.height);
				else if (lObj.type == "Ellipse") boxesCache[lName][lObjName] = new Ellipse(lObj.x, lObj.y, lObj.width/2, lObj.height/2);
				else if (lObj.type == "Circle") boxesCache[lName][lObjName] = new Circle(lObj.x, lObj.y, lObj.radius);
				else if (lObj.type == "Point") boxesCache[lName][lObjName] = new Point(lObj.x, lObj.y);

			}
			
		}
		
	}
	
	/**
	 * Cherche dans le cache général des boxes, celle correspondant au state demandé
	 * @param	pState State de l'instance
	 * @return	la box correspondante
	 * @return
	 */
	public function getBox (pState:String):Map<String,Dynamic> {
		return boxesCache[assetName+"_" +pState];
	}		
	
	/**
	 * met en pause l'anim
	 */
	public function pause ():Void {
		if (anim != null) anim.stop();
	}
	
	/**
	 * relance l'anim
	 */
	public function resume ():Void {
		if (anim != null) anim.play();
	}
	
	/**
	 * retourne la zone de hit de l'objet
	 */
	public var hitBox (get, null):Container;
	 
	private function get_hitBox (): Container {
		return box;
		// Si on veut cibler une box plus précise: return box.getChildByName("nom d'instance du MovieClip de type Rectangle ou Circle dans Flash IDE");
	}

	/**
	 * retourne un tableau de points de collision dont les coordonnées sont exprimées dans le systeme global
	 */
	public var hitPoints (get, null): Array<Point>;
	 
	private function get_hitPoints (): Array<Point> {
		return null;
		// liste de Points : return [box.toGlobal(box.getChildByName("nom d'instance du MovieClip de type Point dans Flash IDE").position,box.toGlobal(box.getChildByName("nom d'instance du MovieClip de type Point dans Flash IDE").position];
	}
	public function getAssetName():String{
		return assetName;
	}
	/**
	 * nettoyage et suppression de l'instance
	 */
	override public function destroy (): Void {
		anim.stop();
		removeChild(anim);
		anim.destroy();		
		if (box != anim) {
			removeChild(box);
			box.destroy();
			box = null;
		}
		anim = null;
		
		super.destroy();
	}
	
}