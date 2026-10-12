// Controlled display fixtures. Original hurtHero bytecode and symbol timelines
// are retained by BuildReference. No expected port observations are injected.
stop();
Stage.scaleMode = "noScale";
Stage.align = "TL";
game = this;
w = 15;
d = 30;
pausing = false;
totalPlayer = 1;
createEmptyMovieClip("brickArea", 2);
if (scenario == "counts") {
    var backdrop = createEmptyMovieClip("backdrop", 1);
    backdrop.beginFill(0x202020);
    backdrop.moveTo(0,0); backdrop.lineTo(550,0); backdrop.lineTo(550,400);
    backdrop.lineTo(0,400); backdrop.lineTo(0,0); backdrop.endFill();
}
actors = [];
if (scenario == "hit") {
    createEmptyMovieClip("bgArea", 1);
    var y = 0;
    while (y < 13) {
        var x = 0;
        while (x < 15) {
            var floor = bgArea.attachMovie("bg", "floor" + y + "_" + x, y * 15 + x, {_x:x*30,_y:y*30});
            floor.gotoAndStop(1);
            x++;
        }
        y++;
    }
    var center = brickArea.attachMovie("brick", "center", calDepth(6,6,10), {_x:180,_y:150});
    center.gotoAndStop(52);
    var hero = brickArea.attachMovie("hero1", "hero2", calDepth(8,7,10)-2, {_x:240,_y:210,heroNum:2,heroId:1,life:2,varShield:0});
    hero.gotoAndStop("down");
    hero.body.stop();
    actors.push(hero);
    hurtHero(hero);
} else {
    var i = 0;
    var count = scenario == "weapons" || scenario == "depth" || scenario == "counts" ? 6 : scenario == "walk" ? 16 : 8;
    while (i < count) {
        var character = i % 4 + 1;
        var column = scenario == "weapons" ? i : i % 4;
        var row = scenario == "weapons" ? 0 : int(i / 4);
        var hero = brickArea.attachMovie("hero" + character, "hero" + i, 100+i, {_x:60+column*90,_y:100+row*80,heroNum:int(i/4)+1,heroId:character,totalSpecial:i+1});
        hero.gotoAndStop(scenario == "walk" ? row+1 : 4);
        hero.body.stop();
        if (scenario == "walk") hero.body.play();
        if (scenario == "depth") {
            hero._x = (2 + i*2)*30;
            hero._y = 180;
            hero.swapDepths(calDepth(2+i*2,6,10)-1);
            var brick = brickArea.attachMovie("brick", "brick" + i, calDepth(2+i*2,6,10), {_x:hero._x,_y:hero._y});
            brick.gotoAndStop(1);
        }
        if (scenario == "counts") {
            hero._x = 60+i*60;
            hero._y = 100;
            hero.totalSpecial = [1,2,10,11,12,20][i];
        }
        if (scenario == "weapons" || scenario == "depth" || scenario == "counts") {
            hero.attachMovie("specialToolViewer", "specialToolViewer", 0);
            hero.specialToolViewer.tool.gotoAndStop(i+7);
        } else if (scenario == "pointer") {
            var pointer = hero.attachMovie("p_pointer", "p_pointer", 0, {delayTime:150});
            pointer.p.gotoAndStop(i+1);
            pointer.arrow.gotoAndStop(character);
            // Source frame-2 setup callback, copied verbatim, not port logic.
            pointer.onEnterFrame = function() {
                if(pausing) { return 0; }
                if(--this.delayTime <= 0) { this.removeMovieClip(); }
            };
        }
        actors.push(hero);
        i++;
    }
}
tick = -1;
this.onEnterFrame = function() {
    tick++;
    if (scenario == "counts" && tick == 0) {
        var j = 0;
        while (j < actors.length) {
            var field = actors[j].specialToolViewer.getInstanceAtDepth(-16368);
            trace("COUNT_METRICS|" + actors[j].totalSpecial + "|" + field.textWidth + "|" + field.textHeight + "|" + field.getTextFormat().font + "|" + field.getTextFormat().size);
            j++;
        }
    }
    var pointer = actors[0].p_pointer;
    var smoke = brickArea.heroDieSmoke2;
    trace("FEEDBACK_SAMPLE|" + tick + "|" + actors[0].body._currentframe
        + "|" + (pointer != undefined)
        + "|" + (pointer == undefined ? 0 : Math.round(pointer.p._y * 20))
        + "|" + (scenario == "hit" ? actors[0].life : 0));
};
