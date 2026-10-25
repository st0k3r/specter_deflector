--default sprite fields - read through the metatable until overwritten
sprmeta={__index={x=0,y=0,sx=0,sy=0,flash=0,shake=0,frame=1,width=1,height=1,w=8,h=8}}

--wave layouts: 4 rows of 10, 0=empty, 1-5=creature type
wave_data=split([[
0111111110 0111111110 0111111110 0111111110
0222222220 0222222220 0222222220 0222222220
1122112211 1122222211 2222222222 2222222222
0333333330 0333333330 0333333330 0333333330
3301111033 3301111033 3301111033 3301111033
0122112210 3122112213 3122222213 0122222210
3131221313 1312112131 3131221313 1312112131
2220400222 2200000022 1101111011 1101111011
3301111033 4002222040 0002112000 1101111011
0011111100 3311111133 3322222233 3322222233
0000500000 0000000000 0000000000 0000000000]],"\n",false)

--default functions
function _init()
	cartdata("st0k3r")
	highscore=dget(0)
	hightime=dget(1)
	mode="start"
	t=0
	shake=0
	flash=0
	music(8)
	set_transparency()
	randpos()
	upd={game=update_game,start=update_start,wavetext=update_wavetext,over=update_over,win=update_win}
	drw={game=draw_game,start=draw_start,wavetext=draw_wavetext,over=draw_end,win=draw_end}
end

--gameplay
function _update()
	t+=1
	upd[mode]()
end

--draws frame
function _draw()
	do_shake()
	drw[mode]()
end

--update functions

--game state - called when mode is set to  "game"
function update_game()
	controls()
	ghost.x+=ghost.xspeed
	ghost.y+=ghost.yspeed
	bullet_movement()
	creature_movement()
	collision_bullet()
	collision_creature_ghost_bullets()
	collision_ghost()
	collision_creature_bullet()
	for pickup in all(pickups) do
		if collision(pickup,ghost) then
			pickup_logic(pickup)
			del(pickups,pickup)
		end
	end

	if lives<=0 then
		end_game("over")
		sfx(-1)
		music(7)
	end

	muzzle=max(muzzle-1)

	--ghost stops at edges, or wraps horizontally in ghost mode
	local g=ghost.mode==1
	if ghost.x>120 then
		ghost.x=g and 0 or 120
	end
	if ghost.x<0 then
		ghost.x=g and 120 or 0
	end
	ghost.y=mid(0,ghost.y,120)

	if mode=="game" then
		if t>next_fire then
			pick_fire()
			next_fire=t+firefreq+rnd(firefreq)
		end
		if t%freq==0 then
			pick_attack()
		end
	end

	if mode=="wavetext" then
		animate_background(2)
	else
		animate_background(1)
	end

	timer_seconds=t\30

	if mode=="game" and #creatures==0 then
		creature_bullets={}
		next_wave()
	end
end

--start state - called when mode is set to "start"
function update_start()
	if pressed() then
		start_game()
	end
	animate_background()
end

--true once z/x is pressed after both buttons have been released
function pressed()
	if not (btn(4) or btn(5)) then
		btn_released=true
	end
	if btn_released and (btnp(4) or btnp(5)) then
		btn_released=false
		return true
	end
end

--over/win states - returns to start screen after lockout
function update_over()
	if t>=lockout and pressed() then
		if mode=="over" or win_music_pending then
			music(8)
		end
		mode="start"
		win_music_pending=false
	end
end

--updates wave text at beginning of each wave and starts next wave
function update_wavetext()
	update_game()
	wavetime-=1
	if wavetime<=0 then
		mode="game"
		spawn_wave()
	end
end

--win state - called when mode is set to "win"
function update_win()
	if win_music_pending and not sfx_playing(19) then
		music(8)
		win_music_pending=false
	end
	update_over()
end

--sets ghost speed and sprite from button input
--btn(4) = z (Ghost mode)
--btn(5) = x (Shoot + Bombs)
--btn(0-3) = left, right, up, down
--ghost mode sprites are the normal sprite +29
function controls()
	local o=ghost.mode==1 and 29 or 0
	ghost.xspeed=0
	ghost.yspeed=0
	ghost.spr=2+o
	if t<=controlled_timer then
		ghost.yspeed=-1
		ghost.spr=4+o
	end
	ghost.mode=0

	if btn(4) and invul<=0 and bombs>0 and wavetime<=0 then
		ghost.mode=1
		bombs-=0.1
		if bombs<=0 then
			sfx(9)
		end
		sfx_check+=1
		if sfx_check==1 then
			sfx(8)
		end
	end
	if btn(4) and btnp(5) and invul<=0 and wavetime<=0 then
		if bombs>0 then
			ghost_bomb()
			bombs=0
		else
			no_candy()
		end
	end
	if btnp(4) and bombs<=0 then
		no_candy()
	end
	if btn(5) and bullet_timer<=0 and ghost.mode!=1 then
		add(bullets,makespr{x=ghost.x,y=ghost.y-3,spr=6,w=4,h=4,sy=-4,dmg=1})
		sfx(0)
		muzzle=5
		bullet_timer=4
	end

	local g=ghost.mode==1
	local m,s=g and 2 or 1,g and 29 or 0
	if btn(0) then
		ghost.xspeed=-2*m
		ghost.spr=1+s
	end
	if btn(1) then
		ghost.xspeed=2*m
		ghost.spr=3+s
	end
	if t>controlled_timer then
		if btn(2) then
			ghost.yspeed=-2*m
			ghost.spr=4+s
		end
		if btn(3) then
			ghost.yspeed=2*m
			ghost.spr=5+s
		end
	end
	bullet_timer-=1

	--stops ghost mode sfx when z is released
	local down=btn(4)
	if is_holding and not down then
		sfx_check=0
		if bombs>0 and wavetime<=0 then
			sfx(9)
		end
	end
	is_holding=down
end

--true when obj is off the bottom or sides of the screen
function out(obj)
	return obj.y>128 or obj.x<-8 or obj.x>128
end

--moves bullets and pickups, deleting them when off screen
function bullet_movement()
	for bullet in all(bullets) do
		move(bullet)
		if bullet.y<-8 then
			del(bullets,bullet)
		end
	end

	for creature_bullet in all(creature_bullets) do
		move(creature_bullet)
		animate(creature_bullet)
		if creature_bullet.y<-8 or out(creature_bullet) then
			del(creature_bullets,creature_bullet)
		end
	end

	for pickup in all(pickups) do
		move(pickup)
		if out(pickup) then
			del(pickups,pickup)
		end
	end
end

--handles movement of creatures
function creature_movement()
	for creature in all(creatures) do
		creature_do(creature)
		animate(creature)
		if creature.mission!="fly_in" and out(creature) then
			del(creatures,creature)
		end
	end
end

--checks for collision with bullet and creature and deletes bullet at time of collision
function collision_bullet()
	for c in all(creatures) do
		for bullet in all(bullets) do
			if collision(c,bullet) then
				del(bullets,bullet)
				make_wave(bullet.x+4,bullet.y+4,11)
				make_slime(c.x+4,c.y+4)

				if c.mission!="fly_in" then
					c.hp-=bullet.dmg
				end

				sfx(3)
				c.flash=c.boss and 5 or 2

				--damaged animations
				if c.hp<=10 and c.type==4 then
					set_anim(c,"98,98,100,102,104,106,108,110,128")
				end
				if c.hp<3 then
					if c.type==1 then
						set_anim(c,c.has_fired and "49,49,50,50" or "28,28,29,29")
					elseif c.type==2 then
						set_anim(c,"24,25")
					elseif c.type==3 then
						set_anim(c,c.mission=="attack" and "37,38,39" or "16,17,18")
					end
				end

				if c.hp<=0 then
					kill_creature(c)
					break
				end
			end
		end
	end
end

--bomb bullets destroy creature bullets
function collision_creature_ghost_bullets()
	for bullet in all(bullets) do
		if bullet.spr==8 then
			for creature_bullet in all(creature_bullets) do
				if collision(bullet,creature_bullet) then
					del(creature_bullets,creature_bullet)
					score+=5
					make_wave(creature_bullet.x,creature_bullet.y,11)
				end
			end
		end
	end
end

--checks for collision with ghost and creature
function collision_ghost()
	if invul>0 then
		invul-=1
	elseif ghost.mode!=1 then
		for creature in all(creatures) do
			if collision(creature,ghost) then
				lives-=1
				invul=60
				ghost_hit()
				return
			end
		end
	end
end

--checks for collision with ghost and creature bullet
function collision_creature_bullet()
	if invul<=0 and ghost.mode!=1 then
		for cb in all(creature_bullets) do
			if collision(cb,ghost) then
				local s,txt=cb.spr
				invul=60
				if s==46 or s==51 then
					lives-=2
					txt="headshot!"
				elseif s>131 and s<135 then
					lives-=1
					controlled_timer=t+60
					invul=0
					txt="controlled!"
				else
					lives-=1
					if s>39 and s<43 then
						max_lives-=1
						txt="poisoned"
					elseif s>147 then
						bombs=0
						txt="tricked!"
					end
				end
				if txt then
					show_float(txt,cb.x,cb.y)
				end
				ghost_hit()
				del(creature_bullets,cb)
				return
			end
		end
	end
end

--explosion, shake and sfx when ghost is hit
function ghost_hit()
	spawn_explosion(ghost.x+4,ghost.y+4,true)
	shake=10
	flash=2
	if lives>=1 then
		sfx(1)
		ghost.x=60
		ghost.y=100

	end
end

--ends the game in "over" or "win" mode and records high score/time
function end_game(m)
	mode=m
	if score>highscore then
		new_hs=true
		highscore=score
		dset(0, score)
	end
	if timer_seconds>hightime then
		new_ht=true
		hightime=timer_seconds
		dset(1, timer_seconds)
	end
	lockout=t+30
end

--makes background assets move
function animate_background(spd)
	if spd==nil then
		spd=1
	end

	for g in all(sprtable) do
		g.y+=spd*spd
		if g.y>128 then
			g.y-=128
		end
	end
end

--creates sprite obj from a table of fields, missing fields use sprmeta defaults
function makespr(o)
	return setmetatable(o,sprmeta)
end

--sets animation from a "spr,spr,..." string and shows its first frame
function set_anim(o,s)
	o.animation=split(s)
	o.spr=o.animation[1]
end

--function for screen shake
function do_shake()
	camera(rnd(shake)-shake/2,rnd(shake)-shake/2)

	if shake>10 then
		shake*=0.9
	else
		shake-=1
		if shake<1 then
			shake=0
		end
	end
end

--draw functions

--draws game - called when mode is set to "game"
function draw_game()
	if flash>0 then
		flash-=1
		cls(2)
	else
		cls(3)
	end
	draw_graveyard()

	--floating text messages, deleted after timeout period
	for float in all(floats) do
		center_print(float.txt,float.x,float.y,t%4<2 and 8 or 7)
		float.y-=0.5
		float.age+=1
		if float.age>60 then
			del(floats,float)
		end
	end
	floater_timeout-=1

	--pickups w/ flashing outline to stand out from creatures and projectiles
	for pickup in all(pickups) do
		for i=1,15 do
			pal(i,t%4<1 and 14 or 7)
		end
		for i=-1,1,2 do
			spr(pickup.spr,pickup.x+i,pickup.y)
			spr(pickup.spr,pickup.x,pickup.y+i)
		end
		pal()
		set_transparency()
		draw_spr(pickup)
	end

	--creatures w/ flash effect upon being hit
	for creature in all(creatures) do
		if creature.flash>0 then
			if t%4<2 then
				pal(4,8)
				pal(9,14)
			end
			creature.flash-=1
			if creature.boss then
				creature.spr=200
			else
				for i=0,15 do
					pal(i,7)
				end
			end
		end
		draw_spr(creature)
		pal()
		set_transparency()
	end

	--ghost blinks while invulnerable
	if lives>0 and (invul<=0 or sin(t/5)<0.1) then
		draw_spr(ghost)
	end

	for bullet in all(bullets) do
		draw_spr(bullet)
	end

	if muzzle>0 then
		circfill(ghost.x+3,ghost.y,muzzle,11)
		circfill(ghost.x+4,ghost.y,muzzle,11)
	end

	for w in all(shockwaves) do
		circ(w.x,w.y,w.size,w.col)
		w.size+=w.speed
		if w.size>w.maxsize then
			del(shockwaves,w)
		end
	end

	--particles: green, or white fading to dark red with age
	for e in all(explosions) do
		local a=e.age
		local pc=e.green and 11 or a>15 and 5 or a>12 and 2 or a>7 and 13 or a>5 and 6 or 7
		if e.spark then
			pset(e.x,e.y,pc)
		else
			circfill(e.x,e.y,e.size,pc)
		end
		e.x+=e.dx
		e.y+=e.dy
		e.dx*=0.85
		e.dy*=0.85
		e.age+=1
		if e.age>e.maxage then
			e.size-=0.5
			if e.size<0 then
				del(explosions,e)
			end
		end
	end

	for creature_bullet in all(creature_bullets) do
		draw_spr(creature_bullet)
	end

	--ui: score, lives, bombs (candy)
	if mode=="game" then
		print("score:"..make_score(score),51,2,8)
	end
	for i=1,min(lives,4) do
		spr(7,i*9-8,1)
	end
	spr(bombs_sprite,108,0)
	print(ceil(bombs),118,1,14)
end

--draws start screen - called when mode is set to "start"
function draw_start()
	cls(3)
	draw_graveyard()
	spr(135, 27, 20, 9, 4)
	if highscore>0 then
		center_print("high score:",64,56,8)
		center_print(make_score(highscore),64,64,8)
	end
	if hightime>0 then
		center_print("high time:",64,72,8)
		center_print(format_time(hightime),64,80,8)
	end
	center_print("press ❎ to start",64,96,blink())
end

--draws game over / win screen - called when mode is "over" or "win"
function draw_end()
	draw_game()
	local c=t%4<2 and 10 or 7
	center_print(mode=="win" and "the horde is gone...for now" or "r.i.p.",64,32,blink())
	center_print("score:"..make_score(score),64,42,blink())
	if new_hs then
		center_print("new high score!",64,49,c)
	end
	center_print(format_time(timer_seconds),64,59,blink())
	if new_ht then
		center_print("new high time!",64,66,c)
	end
	center_print("press ❎ to continue",64,76,blink())
end

--draws wave text shown at beginning of each wave
function draw_wavetext()
	draw_game()
	center_print(wave==11 and "boss wave" or "wave "..wave.." of 10",64,40,blink())
	center_print(format_time(timer_seconds),64,49,blink())
end

--formats a number of seconds as m:ss
function format_time(total_seconds)
	return total_seconds\60 ..":"..sub("0"..total_seconds%60,-2)
end

--draws background assets
function draw_graveyard()
	for g in all(sprtable) do
		spr(g.s,g.x,g.y)
	end
end

function make_score(val)
	return val==0 and "0" or val.."00"
end

--initialization

--called to start gameplay
function start_game()
	music(6)
	wave=0
	timer_seconds=0

	next_wave()

	ghost=makespr{spr=2,x=60,y=90}
	controlled_timer,bullet_timer,muzzle,score,bombs,next_fire,invul=0,0,0,0,0,0,0
	max_lives=4
	lives=4

	bombs_sprite=rnd(split"52,53,54")

	randpos()

	bullets,creature_bullets,creatures,explosions,shockwaves,pickups,floats={},{},{},{},{},{},{}

	t=0
	floater_timeout=60
	new_hs=false
	new_ht=false
end

--removes transparency from black(0) and adds to pink(14) instead
function set_transparency()
	palt(0,false)
	palt(14,true)
end

--generates 40 background graves at random grid cells with random sprites
function randpos()
	local ids={}
	for i=0,63 do
		add(ids,i)
	end
	sprtable={}
	for i=1,40 do
		local v=del(ids,rnd(ids))
		add(sprtable,{x=v%8*16,y=v\8*16,s=rnd(split"10,11,12")})
	end
end

--makes start/over screen text blink red
function blink()
	return t%36<12 and 0 or 8
end

--function to draw all sprite objects
function draw_spr(sp)
	local x,y=sp.x,sp.y

	if sp.shake>0 then
		sp.shake-=1
		if t%4<2 then
			x+=1
		end
	end

	if sp.bulletmode then
		x+=1
		y-=1
	end

	spr(sp.spr,x,y,sp.width,sp.height,sp.sx<0)
end

--collision detection
function collision(a,b)
	return not (a.no_interact or b.no_interact
		or a.y>b.y+b.h-1 or b.y>a.y+a.h-1
		or a.x>b.x+b.w-1 or b.x>a.x+a.w-1)
end

--creates creature obj and and adds it to list
--1: Frank
--2: Witch
--3: Drac
--4: UFO
--5: Jack (boss)
--data per type: hp,anispeed,width,height,score,animation...
function spawn_creature(ty,x,y,wait)
	local d=split(split("3,0.1,1,1,1,26,26,27,27|2,0.1,1,1,2,22,23|4,0.1,1,1,3,13,14,15|20,1,2,2,5,64,66,68,70,72,76,78,96|130,1,4,3,0,196","|")[ty])
	local c=makespr{
		x=x*2-64,y=y-66,posx=x,posy=y,
		type=ty,wait=wait,mission="fly_in",
		hp=d[1],anispeed=d[2],
		width=d[3],height=d[4],w=d[3]*8,h=d[4]*8,
		score=d[5],animation={unpack(d,6)}
	}
	c.spr=c.animation[1]
	if ty==5 then
		c.x=48
		c.y=-24
		c.posx=48
		c.posy=25
		c.boss=true
	end
	add(creatures,c)
end

--adds a particle to the explosions list
function add_part(x,y,dx,dy,age,size,maxage,green,spark)
	add(explosions,{x=x,y=y,dx=dx,dy=dy,age=age,size=size,maxage=maxage,green=green,spark=spark})
end

--adds n particles flying out at random speeds
function burst(x,y,n,spd,off,size,maxage,green,spark)
	for i=1,n do
		add_part(x,y,(rnd()-0.5)*spd-off,(rnd()-0.5)*spd-off,rnd(2),1+rnd(size),maxage+rnd(10),green,spark)
	end
end

--creates explosion particles
function spawn_explosion(x,y,green)
	add_part(x,y,0,0,0,10,0,green)
	burst(x,y,30,6,3,4,10,green)
	burst(x,y,20,10,0,4,10,green,true)
end

function spawn_boss_explosion(x,y)
	add_part(x,y,0,0,0,25,0)
	burst(x,y,60,12,6,6,20)
	burst(x,y,100,30,0,4,20,nil,true)
end

--function to create shockwave upon bullet/enemy collision (small) or enemy explosion (big)
function make_wave(x,y,col,big)
	add(shockwaves,{x=x,y=y,col=col,size=big and 3.5 or 3,maxsize=big and 20 or 5,speed=big and 3 or 1})
end

--makes bullet collision particle effect for creatures
function make_slime(x,y)
	add_part(x,y,(rnd()-0.5)*8,(rnd()-1)*3,rnd(2),1+rnd(4),10+rnd(10),true,true)
end

--function to show floating text messages
function show_float(txt,x,y)
	add(floats,{x=x,y=y,txt=txt,age=0})
end

--shows "no candy..." float, limited by timeout
function no_candy()
	if floater_timeout<=0 then
		sfx(13)
		show_float("no candy...",ghost.x+4,ghost.y+4)
		floater_timeout=60
	end
end

--center print text
function center_print(txt,x,y,c)
	print(txt,x-#txt*2,y,c)
end

--waves and enemies

--spawns creatures for the current wave from wave_data
function spawn_wave()
	local f=split"60,20,60,20,60,20,50,15,50,15,50,15,40,10,40,10,30,10,30,10,60,20"
	freq=f[wave*2-1]
	firefreq=f[wave*2]
	local lvl=wave_data[wave]
	for i=0,39 do
		local ty=ord(lvl,i+i\10+1)-48
		if ty>0 then
			if wave<11 then
				sfx(7)
			else
				music(9)
			end
			local x=i%10+1
			spawn_creature(ty,x*12-6,16+i\10*12,x*4)
		end
	end
end

--increments wave and checks if game has completed
function next_wave()
	wave+=1
	sfx_check=0
	is_holding=false

	if wave>11 then
		end_game("win")
		win_music_pending=true
	else
		mode="wavetext"
		wavetime=wave==1 and 110 or 80
		if wave>1 and wave!=11 then
			sfx(6)
		end
	end
end

--checks if a given sfx is still playing on any channel
function sfx_playing(n)
	for i=16,19 do
		if stat(i)==n then
			return true
		end
	end
end

--behaviors

--runs the creature's mission function (fly_in, attack, boss_1..boss_5), "hover" has none
function creature_do(creature)
	if creature.wait>0 then
		creature.wait-=1
		return
	end
	local f=_ENV[creature.mission]
	if f then
		f(creature)
	end
end

--creature flies from spawn point to its formation position
function fly_in(c)
	local dx=(c.posx-c.x)/7
	local dy=(c.posy-c.y)/7

	if c.boss then
		dx=min(dx,1.5)
		dy=min(dy,1.5)
	end

	c.x+=dx
	c.y+=dy

	if abs(c.y-c.posy)<0.7 then
		c.y=c.posy
		c.mission="hover"
		if c.boss then
			sfx(40)
			c.mission="boss_1"
			c.shake=20
			c.wait=28
			c.phbegin=t
		end
	end
end

--creature dives at the ghost
function attack(c)
	local ty=c.type
	if ty==1 then
		c.sy=1
		if c.has_fired then
			c.sx=sin(t/45)
		elseif c.y>ghost.y then
			c.sx=0
			if invul<=0 and ghost.mode!=1 and c.y<127 then
				aimedfire(c,2)
				c.sx=sin(t/45)
				frank_aim(c)
			end
		elseif invul<=0 and ghost.mode!=1 then
			move_ang(c,atan2(ghost.y-c.y,ghost.x-c.x),1)
		else
			c.sx=0
		end
		steer(c)
	elseif ty==2 then
		c.sy=2.5
		c.sx=sin(t/20)
		steer(c)
	elseif ty==3 then
		if c.sx==0 then
			c.sy=2
			if ghost.y<=c.y then
				c.sy=0
				c.sx=ghost.x<c.x and -2 or 2
			end
		end
	elseif ty==4 then
		c.sy=0.3
		if c.y>110 then
			c.sy=1
		elseif t%30==0 then
			spreadshot(c,8,1.3,rnd())
		end
	end
	move(c)
end

--pushes diving creatures back toward the middle of the screen
function steer(c)
	if c.x<32 then
		c.sx+=1-c.x/32
	end
	if c.x>88 then
		c.sx-=(c.x-88)/32
	end
end

--frank's firing animation
function frank_aim(c)
	set_anim(c,c.hp>=3 and "47,47,48,48" or "49,49,50,50")
end

--picks one of the last 10 creatures in the list
function pick_creature()
	return creatures[#creatures-flr(rnd(min(10,#creatures)))]
end

--picks a creature to fly down and attack ghost
function pick_attack()
	local c=pick_creature()

	if c and c.mission=="hover" then
		c.mission="attack"
		if c.type==3 then
			c.anispeed=0.5
			set_anim(c,c.hp>=3 and "19,20,21" or "37,38,39")
		end
		c.wait=30
		c.shake=30
	end
end

--picks a creature to shoot at ghost
function pick_fire()
	local c=pick_creature()

	for ufo in all(creatures) do
		if ufo.type==4 and ufo.mission=="hover" and rnd()<0.5 then
			spreadshot(ufo,12,1.3,rnd())
			return
		end
	end

	if c and c.mission=="hover" then
		if c.type==4 then
			spreadshot(c,12,1.3,rnd())
		elseif c.type==2 then
			if ghost.mode!=1 then
				aimedfire(c,2)
			else
				fire(c,0,2)
			end
		elseif c.type==1 then
			if not c.has_fired then
				frank_aim(c)
			end
			fire(c,0,2)
		end
	end
end

--function to move object
function move(obj)
	obj.x+=obj.sx
	obj.y+=obj.sy
end

--called when creature hp is equal to or less than 0
function kill_creature(c)
	if c.boss then
		c.mission="boss_5"
		c.phbegin=t
		c.no_interact=true
		creature_bullets={}
		sfx(41)
		return
	end

	del(creatures,c)
	sfx(2)

	spawn_explosion(c.x+4,c.y+4)
	make_wave(c.x+4,c.y+4,6,true)

	local pickup_chance=0.1

	if c.mission=="attack" then
		if rnd()<0.5 then
			pick_attack()
		end
		show_float("busted!",c.x+4,c.y+4)
		pickup_chance=0.2
	end

	score+=c.score+2

	if rnd()<pickup_chance then
		add(pickups,makespr{x=c.x,y=c.y,sy=0.75,spr=rnd(split"52,53,54")})
	end
end

--pickup logic
function pickup_logic(pickup)
	bombs+=1
	make_wave(pickup.x+4,pickup.y+4,14)

	if bombs>=10 then
		if lives<max_lives then
			lives+=1
			sfx(12)
			show_float("ghoulish!",pickup.x+4,pickup.y+4)
		else
			score+=50
			show_float("unleashed!",pickup.x+4,pickup.y+4)
			ghost_bomb()
		end
		bombs=0
	else
		sfx(11)
	end
end

-- animation function - code was originally written for creatures, but has been repurposed for all sprites
function animate(o)
	o.frame+=o.anispeed

	if flr(o.frame)>#o.animation then
		o.frame=1
	end

	o.spr=o.animation[flr(o.frame)]
end

--bullets

--creature shoots a projectile at angle ang
function fire(c,ang,spd)
	sfx(c.boss and 18 or 10)
	local b=makespr{x=c.x-1,y=c.y,w=5,h=5,anispeed=0.1,bulletmode=true}
	local ty=c.type

	if ty==4 then
		b.x=c.x+4
		b.y=c.y+12
		b.anispeed=1
		set_anim(b,"43,44,45,44,43")
	elseif ty==1 then
		--head on first shot, random body parts after
		b.anispeed=1
		set_anim(b,c.has_fired and rnd(split("55,55|56,56,57,57,58,58,59,59|60,60,61,61,62,62,63,63","|")) or c.hp<3 and "51,51" or "46,46")
		c.has_fired=true
	elseif ty==2 then
		--poison always, control unless already controlled, trick only if ghost has candy
		local p={"40,41,42"}
		if controlled_timer<t then
			add(p,"132,133,134")
		end
		if bombs>0 then
			add(p,"148,149,150")
		end
		set_anim(b,rnd(p))
	else
		if c.boss then
			b.x=c.x+11
			b.y=c.y+22
		end
		set_anim(b,"9,9")
	end

	move_ang(b,ang,spd)
	add(creature_bullets,b)
	return b
end

--ufo spreadshot
function spreadshot(c,num,spd,base)
	for i=1,num do
		fire(c,1/num*i+base,spd)
	end
end

--witches projectile - targeted at ghost
function aimedfire(c,spd)
	local b=fire(c,0,spd)
	move_ang(b,atan2(ghost.y+4-b.y,ghost.x+4-b.x),spd)
end

--sets obj speed from angle
function move_ang(obj,ang,spd)
	obj.sy=cos(ang)*spd
	obj.sx=sin(ang)*spd
end

--called when player presses fire button while in ghost mode and has bombs (candies)
function ghost_bomb()
	floater_timeout=60
	sfx(14)
	local spacing=0.25/(bombs*2)

	for i=0,bombs*2 do
		local b=makespr{x=ghost.x,y=ghost.y-3,spr=8,dmg=3}
		move_ang(b,0.375+spacing*i,4)
		add(bullets,b)
	end

	make_wave(ghost.x+3,ghost.y+3,6,true)
	shake=5
	muzzle=5
	invul=30
	flash=2
end

--boss bounces side to side for 8 seconds, then switches to mission nxt
function boss_bounce(c,spd,nxt)
	if c.sx==0 or c.x>=93 then
		c.sx=-spd
	end
	if c.x<=3 then
		c.sx=spd
	end
	if c.phbegin+240<t then
		c.mission=nxt
		c.phbegin=t
		c.subphase=1
	end
end

--boss sweeps around the screen edge: dir -1 starts left, 1 starts right
function boss_sweep(c,dir,nxt)
	local d=split"1,0,0,1,-1,0,0,-1"
	local i=c.subphase*2
	c.sx=d[i-1]*dir*1.5
	c.sy=d[i]*1.5
	if c.sx<0 and c.x<=4 or c.sx>0 and c.x>=91 or c.sy>0 and c.y>=100 then
		c.subphase+=1
	elseif c.sy<0 and c.y<=25 then
		c.mission=nxt
		c.phbegin=t
		c.sy=0
	end
end

--boss mission 1 - bounce and rapid fire
function boss_1(c)
	boss_bounce(c,2,"boss_2")
	if t%30>3 and t%3==0 then
		fire(c,0,2.25)
	end
	move(c)
end

--boss mission 2 - sweep and aimed fire
function boss_2(c)
	boss_sweep(c,-1,"boss_3")
	if t%15==0 then
		aimedfire(c,2)
	end
	move(c)
end

--boss mission 3 - slow bounce and spreadshot
function boss_3(c)
	boss_bounce(c,0.5,"boss_4")
	if t%10==0 then
		spreadshot(c,8,2,time())
	end
	move(c)
end

--boss mission 4 - sweep firing toward the edge it travels along
function boss_4(c)
	boss_sweep(c,1,"boss_1")
	if t%12==0 then
		fire(c,(c.subphase-1)/4,2)
	end
	move(c)
end

--boss mission 5 - death sequence
function boss_5(c)
	music(-1)
	c.shake=10
	c.flash=10

	if t%8==0 or c.phbegin+90<t and t%4==2 then
		spawn_explosion(c.x+rnd(32),c.y+rnd(32))
		sfx(2)
	end
	if t%8==0 then
		shake=2
	end

	if c.phbegin+180<t then
		score+=100
		show_float("banished!",c.x+16,c.y+6)
		spawn_boss_explosion(c.x+16,c.y+12)
		shake=15
		flash=2
		creatures={}
		sfx(19)
	end
end
