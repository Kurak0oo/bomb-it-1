// Controlled initial/event state and observations. Original polling, damage,
// ownership, refunds, special callbacks and child timelines execute unchanged.
stop();
if (_parent == undefined) trace("CORE_ERROR|Interaction capture requires a real root parent");
var originalPoll=this.onEnterFrame;
if (typeof(originalPoll)!="function") trace("CORE_ERROR|Original polling callback missing");
var requested = _parent == undefined ? scenario : _parent.scenario;
var fixture;
for (var i=0;i<configuration.scenarios.length;i++) {
    if (configuration.scenarios[i].name==requested) fixture=configuration.scenarios[i];
}
if (fixture==undefined) trace("CORE_ERROR|Unknown interaction scenario");
w=15; h=13; d=30; xy=[[-1,0],[0,-1],[1,0],[0,1]];
totalPlayer=2; pausing=false; brickArea.margin=10; brickScore=10;
for (var y=0;y<h;y++) for (var x=0;x<w;x++) {
    var cell=bgArea.createEmptyMovieClip("bg"+y+"_"+x,y*w+x);
    cell.x=x;cell.y=y;cell.brick="";cell.bomb="";cell.tool="";
    cell.expEnergy=0;cell.expHeroNum=0;
}
for (var i=0;i<fixture.walls.length;i++) {
    var at=fixture.walls[i];bgArea["bg"+at[1]+"_"+at[0]].brick="unbreakAble";
}
for (var n=1;n<=4;n++) {
    var setup=fixture.actors[n-1];
    _parent["heroObj"+n]={life:setup.life,totalBomb:4,score:0,killScore:0,totalScore:0,brickScore:0};
    var hero=brickArea.attachMovie("hero"+n,"hero"+n,calDepth(setup.cell[0],setup.cell[1],10)-n,
        {x:setup.cell[0],y:setup.cell[1],_x:setup.cell[0]*d,_y:setup.cell[1]*d,
         heroNum:n,heroId:n,life:setup.life,varShield:setup.shield,shield:setup.armor,
         moving:true,movId:0,vLevel:6,slowTime:-1,slowVLevel:20,stopTime:0,
         totalBomb:4,bombLevel:1,puttAble:true,prevFire:false,pushBombAble:false,totalSpecial:0});
    hero.gotoAndStop("down");hero.body.stop();
}
// Inert moving actors suppress autonomous AI/input, not original damage checks.
Key={isDown:function(code){return false;},getCode:function(){return 0;}};
function installBomb(spec) {
    var hero=brickArea["hero"+spec.owner];
    var oldX=hero.x;var oldY=hero.y;
    hero.x=spec.cell[0];hero.y=spec.cell[1];
    if (!putBomb(hero)) trace("CORE_ERROR|Fixture bomb rejected");
    var bg=bgArea["bg"+hero.y+"_"+hero.x];
    brickArea[bg.bomb].delayTime=spec.fuse;
    hero.x=oldX;hero.y=oldY;
}
for (var i=0;i<fixture.bombs.length;i++) installBomb(fixture.bombs[i]);
var weaponNames={rocket:"火箭",mine:"地雷",gas:"汽弹",grenade:"手榴弹",fire:"火焰箭",ice:"冰箭"};
for (var i=0;i<fixture.weapons.length;i++) {
    var spec=fixture.weapons[i];var hero=brickArea["hero"+spec.owner];
    var oldX=hero.x;var oldY=hero.y;
    hero.x=spec.cell[0];hero.y=spec.cell[1];hero.moving=false;
    hero.gotoAndStop(spec.face+1);hero.totalSpecial=3;hero.specialToolName=weaponNames[spec.kind];
    if (!putSpecial(hero)) trace("CORE_ERROR|Fixture special rejected");
    hero.x=oldX;hero.y=oldY;hero.moving=true;
}
var tick=-1;
this.onEnterFrame=function() {
    tick++;
    if (tick>=fixture.commands.length) return;
    for (var i=0;i<fixture.events.length;i++) {
        if (fixture.events[i].tick==tick) installBomb(fixture.events[i]);
    }
    originalPoll.call(this);
    var result="CORE_SAMPLE|"+tick;
    for (var n=1;n<=4;n++) {
        var hero=brickArea["hero"+n];var ledger=_parent["heroObj"+n];var alive=hero!=undefined;
        result+="|"+alive+"|"+ledger.life+"|"+(alive ? hero.shield : false)
            +"|"+(alive ? hero.varShield : 0)+"|"+(alive ? Math.max(0,hero.slowTime) : 0)
            +"|"+(alive ? hero.stopTime : 0)+"|"+ledger.totalBomb+"|"+ledger.score;
    }
    var energies="";var owners="";var bombs="";var rockets="";
    for (var y=0;y<h;y++) for (var x=0;x<w;x++) {
        var cell=bgArea["bg"+y+"_"+x];
        if (cell.expEnergy>0) energies+=x+","+y+","+cell.expEnergy+","+cell.expHeroNum+";";
        if (cell.expHeroNum>0) owners+=x+","+y+","+cell.expHeroNum+";";
        if (cell.bomb!="") {
            var bomb=brickArea[cell.bomb];bombs+=x+","+y+","+bomb.heroNum+","+bomb.delayTime+";";
        }
    }
    var counts={rocket:0,mine:0,gasBomb:0,grenade:0,fireArea:0,iceArea:0};
    for (var key in brickArea) {
        var mc=brickArea[key];
        if (typeof(mc)=="movieclip") {
            for (var kind in counts) if (mc._name.indexOf(kind)==0) counts[kind]++;
            if (mc._name.indexOf("rocket")==0) rockets+=mc.heroNum+","+Math.round(mc._x*20)+","+Math.round(mc._y*20)+";";
        }
    }
    for (var key in bgArea) {
        var mc=bgArea[key];
        if (typeof(mc)=="movieclip") {
            if (mc._name.indexOf("fireArea")==0) counts.fireArea++;
            if (mc._name.indexOf("iceArea")==0) counts.iceArea++;
        }
    }
    trace(result+"|"+energies+"|"+owners+"|"+bombs+"|"+rockets
        +"|"+counts.rocket+"|"+counts.mine+"|"+counts.gasBomb+"|"+counts.grenade+"|"+counts.fireArea+"|"+counts.iceArea);
};
