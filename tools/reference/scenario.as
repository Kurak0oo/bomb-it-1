// Only fixture setup and observation. Gameplay functions are original bytecode.
stop();
Stage.scaleMode = "noScale";
Stage.align = "TL";
game = this;
d = 30;
w = 15;
h = 13;
xy = [[-1,0],[0,-1],[1,0],[0,1]];
pausing = false;
totalPlayer = 1;
brickScore = 10;
createEmptyMovieClip("bgArea", 1);
createEmptyMovieClip("brickArea", 2);
brickArea.margin = 10;
var y = 0;
while (y < h) {
    var x = 0;
    while (x < w) {
        var cell = bgArea.createEmptyMovieClip("bg" + y + "_" + x, y * w + x);
        cell.x = x; cell.y = y; cell.brick = ""; cell.bomb = "";
        cell.expEnergy = 0; cell.tool = "";
        x++;
    }
    y++;
}
var character = scenario == "death2" ? 2 : scenario == "death3" ? 3 : scenario == "death4" ? 4 : 1;
var actor = brickArea.attachMovie("hero" + character, "hero1", 500, {_x:240,_y:210,heroNum:1,heroId:character,life:1,varShield:0,totalBomb:0});
actor.gotoAndStop("down");
actor.body.stop();
if (scenario.substr(0, 5) == "death") {
    hurtHero(actor);
    actor.removeMovieClip();
} else {
    actor._visible = false;
    if (scenario == "brick") {
        var obstacle = brickArea.attachMovie("brick", "brick6_9", calDepth(9,6,10), {_x:270,_y:180});
        obstacle.gotoAndStop(1);
        bgArea.bg6_9.brick = "brick6_9";
    }
    var bomb = brickArea.attachMovie("bomb", "bomb6_8", 501, {x:8,y:6,_x:240,_y:180,heroNum:1,heroId:1,bombLevel:1});
    bgArea.bg6_8.bomb = "bomb6_8";
    bombExp(bgArea.bg6_8);
}
tick = -1;
this.onEnterFrame = function() {
    tick++;
    var dying = brickArea.heroExp1;
    var blast = bgArea.expArea6_8;
    // trace works at the original SWF 7 version; ExternalInterface requires 8.
    trace("REFERENCE_SAMPLE|" + tick + "|" + (dying == undefined ? 0 : dying._currentframe)
        + "|" + (dying.hero != undefined) + "|" + (dying.blackHero != undefined)
        + "|" + bgArea.bg6_8.expEnergy + "|" + bgArea.bg6_9.expEnergy
        + "|" + (bgArea.bg6_9.brick != "") + "|" + (blast != undefined));
};
