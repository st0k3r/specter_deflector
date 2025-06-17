--default functions
function _init()
	--clears screen
	cls(0)
	
	--sets default mode
	mode="start"
	
	start_screen()
	
	--create blinkt for use in blink()
	blinkt=0
	
	--frames
	t=0
	
	--plays start screen music
	music(0)
	
	--used to animate background assets on start screen
	set_transparency()
	grave_sprites={10,11,12}
	grave_types={}
	sprtable=randpos()
	graveyard_gen()
	
	--button lockout
	lockout=0
	
	--variable for controlling screen shake
	shake=0
	
	--power-ups for ghost 
	pickups={}
	
	--floater messages
	floats={}
end

--gameplay
function _update()
	--increments blink() array in blink()
	blinkt=blinkt+1
	
	--keeps track of frames
	t=t+1
	
	--state management
	if mode == "game" then
		update_game()
	elseif mode == "start" then
		update_start()
	elseif mode == "wavetext" then
		update_wavetext()
	elseif mode== "over" then
		update_over()
	elseif mode== "win" then
		update_win()
	end
end

--draws frame
function _draw()
	--screen shake
	do_shake()
	
	--state management
	if mode == "game" then
		draw_game()
	elseif mode == "start" then
		draw_start()
	elseif mode == "wavetext" then
		draw_wavetext()
	elseif mode == "over" then
		draw_over()
	elseif mode == "win" then
		draw_win()
	end
end

--update functions

--game state - called when mode is set to  "game"
function update_game()
	set_ghost_params()
	controls()
	z_check()
	ghost_movement()
	bullet_movement()
	move_pickups()
	creature_movement()
	collision_bullet()
	collision_ghost()
	collision_creature_bullet()
	collision_pickups()
	lives_check()
	dec_flash()
	edge_checking()
	picking()
	animate_background()
	
	--keeps track of seconds and minutes for game timer
	timer_frames+=1
	if timer_frames==30 then
		timer_seconds+=1
		timer_frames=0
			if timer_seconds==60 then
				timer_seconds=0
				timer_minutes+=1
			end
	end

	--checks if all creatures are eliminated and starts next wave if so
	if mode=="game" and #creatures==0 then
		next_wave()
	end
end

--start state - called when mode is set to "start"
function update_start()
	--button lockout
	if btnp(5)==false and btnp(4)==false then
		btn_released=true
	end
	
	if btn_released==true then
		if btnp(4) or btnp(5) then
			start_game()
			btn_released=false
		end
	end
	animate_background()
end

--over state - called when mode is set to "over"
function update_over()
	--button lockout
	if t<lockout then
		return
	end
	
	if btnp(4)==false and btnp(5) then
		btn_released=true
	end
	
	if btn_released==true then
		if btnp(4) or btnp(5) then
			start_screen()
			music(0)
			btn_released=false
		end
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
	--button lockout
	if t<lockout then
		return
	end
	
	if btnp(4)==false and btn(5)==false then
		btn_released=true
	end
	
	if btn_released then
		if btnp(4) or btnp(5) then
			start_screen()
			btn_released=false
		end
	end
end

--sets ghost speed and sprite
function set_ghost_params()
	ghost.xspeed=0
	ghost.yspeed=0
	
	if ghost.mode==1 then
	--sets ghost mode sprite
		ghost.spr=31
	else
	--sets regular ghost sprite
		ghost.spr=2
	end
	ghost.mode=0
	ghost.bomb=false
end

--controls setup - adjusts sprite and speed based on button input
--btn(4) = z
--btn(5) = x
--btn(0) = left
--btn(1) = right
--btn(2) = up
--btn(3) - down
function controls()
	if btn(4) then
	--ghost mode
		--ghost mode cannot be used during periods of invulnerability ex. after being hit
		if invul<=0 then
			--ghost mode cannot be used if ghost mode timer is depleted
			if ghost_mode_timer>0 then
				--ghost mode cannot be used during wave text
				if wavetime<=0 then
					ghost.mode=1
	 				ghost_mode_timer-=1
				end
	 			if ghost_mode_timer==0 then
				--play sfx if ghost mode is depleted to 0
	 				sfx(9)
	 			end
	 			sfx_check+=1
	 			sfxcheck()
	 		end
		end
 	end
 	if btn(4) and btnp(5) then
	--bomb
		--ghost bomb can only be used if there is at least one bomb in bombs
		if bombs>0 then
			--ghost bomb cannot be used during periods of invulnerability ex. after being hit
			if invul<=0 then
				--ghost bomb can only be used during ghost mode, which requires ghost mode timer to be greater than 0
				if ghost_mode_timer>0 then
					--ghost bomb cannot be used during wave text
					if wavetime<=0 then	
						--number of projectiles fired is based on number of bombs (candy)
						ghost_bomb(bombs)
						bombs=0	
						--using ghost bomb depletes ghost mode to 0
						ghost_mode_timer=0			
					end
				end
			end
		--when no bombs (candy) are available:
		else
			--no message shown during invulnerability ex. after being hit
			if invul<=0 then
				--no message shown during wave text
				if wavetime<=0 then
					--if ghost mode is depleted, show no energy message
					if ghost_mode_timer==0 then
						show_btn_float("no energy...",ghost.x+4,ghost.y+4)
					--if no bombs are available, show no candy message
					else
						show_btn_float("no candy...",ghost.x+4,ghost.y+4)
					end
				end
			end
		end
	end
	--if ghost mode is depleted, show no energy message
	if btnp(4) then
		if ghost_mode_timer<=0 then
			show_btn_float("no energy...",ghost.x+4,ghost.y+4)
		end
	end
 	if btn(5) then
 	--shoot
		--cannot shoot bullets during ghost mode
 		if bullet_timer <=0 and ghost.mode!=1 then
	 		local new_bullet=makespr()
			new_bullet.x=ghost.x
			new_bullet.y=ghost.y-3
			new_bullet.spr=6
			new_bullet.speed=4
			new_bullet.h=4
			new_bullet.w=4
			new_bullet.sy=-4
			new_bullet.dmg=1
			add(bullets,new_bullet)
			
			sfx(0) --shooting sfx
			muzzle=5 --muzzle flash size
			bullet_timer=4
		end
 	end
	if btn(0) then
	--horizontal move left and change sprite and speed based on ghost mode status
		ghost.xspeed=-2
		if ghost.mode==1 then
	 		ghost.spr=30
	 		ghost.xspeed*=2
	 	else
	 		ghost.spr=1
	 	end
	end
	if btn(1) then
	--horizontal move right and change sprite and speed based on ghost mode status
		ghost.xspeed=2
		if ghost.mode==1 then
			ghost.spr=32
			ghost.xspeed*=2
		else
			ghost.spr=3
		end
	end
	if btn(2) then
	--vertical move up and change sprite and speed based on ghost mode status
		ghost.yspeed=-2
		if ghost.mode==1 then
			ghost.spr=33
			ghost.yspeed*=2
		else
			ghost.spr=4
		end
 	end
 	if btn(3) then
 	--vertical move down and change sprite and speed based on ghost mode status
 		ghost.yspeed=2
 		if ghost.mode==1 then
 			ghost.spr=34
 			ghost.yspeed*=2
 		else
 			ghost.spr=5
 		end
 	end
 	--cooldown for shooting
	bullet_timer=bullet_timer-1
end

--ghost mode sfx maintainer
function sfxcheck()
	if sfx_check==1 then
		if wavetime<=0 then
			sfx(8)
		end
	end
end

--checks if z button is pressed/held for ghost mode sfx
function z_check()
	local is_down=btn(4)
	
	if is_holding==true and is_down==false then
		sfx_check=0
		if ghost_mode_timer>0 then
			if wavetime<=0 then
				sfx(9)
			end
		end
	end
	is_holding=is_down
end

--controls ghost direction
function ghost_movement()
	ghost.x=ghost.x+ghost.xspeed
	ghost.y=ghost.y+ghost.yspeed
end

--controls bullet direction and deletes them when off screen
function bullet_movement()
--ghost bullets
	for bullet in all(bullets) do
		move(bullet)
		if bullet.y<-8 do
			del(bullets,bullet)
		end	
	end
	
	--creature bullets
	for creature_bullet in all(creature_bullets) do
		move(creature_bullet)
		--creature bullet animation
		animate(creature_bullet)
		
		if creature_bullet.y>128 or creature_bullet.y<-8 or creature_bullet.x<-8 or creature_bullet.x>128 then
			del(creature_bullets,creature_bullet)
		end	
	end
end

--moves pickups dropped by killed creatures and deletes them when off-screen
function move_pickups()
	for pickup in all(pickups) do
		move(pickup)
		
		if pickup.y>128 then
			del(pickups,pickup)
		end
	end
end

--handles movement of creatures
function creature_movement()
	for creature in all(creatures) do
		creature_do(creature)
		
		--creature animation
		animate(creature)
		
		--prevents innappropriate deletion of creatures that are not yet on the screen because of "fly_in" mission
		if creature.mission!="fly_in" then
			if creature.y>128 or creature.x<-8 or creature.x>128 then
				del(creatures,creature)
			end
		end
	end
end

--checks for collision with bullet and creature and deletes bullet at time of collision
function collision_bullet()
	for creature in all(creatures) do
		for bullet in all(bullets) do
			if collision(creature,bullet) then
				del(bullets,bullet)
				--circle wave animation at site of collision
				make_small_wave(bullet.x+4,bullet.y+4)
				--slime spatter animation
				make_slime(creature.x+4,creature.y+4)
				--decrements creature health
				creature.hp=creature.hp-bullet.dmg
				sfx(3)
				--show flash animation
				if creature.boss==true then
				--flash duration is longer for boss creatures
					creature.flash=5
				else
					creature.flash=2
				end
				
				--ufo slime spatter effect
				if creature.hp<=10 then
					if creature.type==4 then
						creature.spr=98
						creature.animation={98,98,100,102,104,106,108,110,128}
					end
				end
				
				--other creatures slime spatter effect
				if creature.hp<3 then
					if creature.type==1 then
					--frank
						if creature.has_fired==true then
						--headless frank effect
							creature.spr=49
							creature.animation={49,49,50,50}
						else
							creature.spr=28
							creature.animation={28,28,29,29}
						end
					elseif creature.type==2 then
					--witch
						creature.spr=24
						creature.animation={24,25}
					elseif creature.type==3 then
					--drac
						creature.spr=16
						creature.animation={16,17,18}
					end
				end
				
				--bat slime spatter effect
				if creature.type==3 and creature.mission=="attack" and creature.hp<3 then
					creature.animation={37,38,39}
				end
				
				--kill creature if hp is 0
				if creature.hp<=0 then
					kill_creature(creature)	
				end
			end
		end
	end
end

--checks for collision with ghost and creature
function collision_ghost()
	--collision disabled during invulnerability caused by being hit or during ghost mode
	if invul<=0 then
		if ghost.mode!=1 then
			for creature in all(creatures) do
				if collision(creature,ghost) then
					lives=lives-1
					--explosion animation at site of collision and shake ffect
					spawn_explosion(ghost.x+4,ghost.y+4,true)
					shake=10
					--sfx(1) is only played if lives is greater than 0 to avoid interrupting game over sfx
					if lives>=1 then
						sfx(1)
					end
					--reset invulnerability timer
					invul=60
				end	
			end
		end
	else
	--deplete invulnerability timer
		invul=invul-1
	end
end

--checks for collision with ghost and creature bullet
function collision_creature_bullet()
	if invul<=0 then
		if ghost.mode!=1 then
			--collision disabled during ghost mode
			for creature_bullet in all(creature_bullets) do
				if collision(creature_bullet,ghost) then
					if creature_bullet.spr==46 or creature_bullet.spr==51 then
					--frank head
						--frank head collision causes 2 damage
						lives=lives-2
						show_float("headshot!",creature_bullet.x,creature_bullet.y)
					elseif creature_bullet.spr>=40 and creature_bullet.spr<=42 then
					--witch potion
						--purple potion causes 1 damage and reduces max lives by 1
						lives-=1
						max_lives-=1
						show_float("poisoned",creature_bullet.x,creature_bullet.y)
					elseif creature_bullet.spr>=132 and creature_bullet.spr<=134 then
						--orange potion causes 1 damage and removes all bombs (candy)
						lives-=1
						bombs=0
						show_float("tricked!",creature_bullet.x,creature_bullet.y)
					elseif creature_bullet.spr>=148 and creature_bullet.spr<=150 then
						--blue potion causes 1 damage and depletes ghost mode
						lives-=1
						ghost_mode_timer=0
						show_float("sapped!",creature_bullet.x,creature_bullet.y)
					else
						--all other creature bullets cause 1 damage
						lives-=1
					end
					--explosion animation at site of collision and shake effect
					spawn_explosion(ghost.x+4,ghost.y+4,true)
					shake=10
					del(creature_bullets,creature_bullet)
					--sfx(1) is only played if lives is greater than 0 to avoid interrupting game over sfx
					if lives>=1 then
						sfx(1)
					end
					--reset invulnerability timer
					invul=60
				end	
			end
		end
	end
end

--collision pickup and ghost
function collision_pickups()
	for pickup in all(pickups) do
		if collision(pickup,ghost) then
			pickup_logic(pickup)
			del(pickups,pickup)
		end
	end
end

--checks if lives has depleted to 0, and changes mode if so
function lives_check()
	if lives<=0 then
		mode="over"
		lockout=t+30
		--kills sfx and plays "over" mode music
		sfx(-1)
		music(7)
		return
	end
end

--decreases size of muzzle flash animation
function dec_flash()
	if muzzle>0 then
		muzzle=muzzle-1
	end
end

--checks if ghost has reached edge and stops further movement
function edge_checking()
	if ghost.x>120 then
		if ghost.mode==1 then
			--ghost can move through side walls during ghost mode
			ghost.x=0
		else
			ghost.x=120
		end
	end
	if ghost.x<0 then
		if ghost.mode==1 then
			ghost.x=120
		else
			ghost.x=0
		end
	end
	if ghost.y>120 then
		ghost.y=120
	end
	if ghost.y<0 then
		ghost.y=0
	end	
end

--makes background assets move
function animate_background()
	for i=1,#sprtable do
		sprtable[i].y=sprtable[i].y+1
		
		if sprtable[i].y>128 do
			sprtable[i].y=sprtable[i].y-128
		end
	end
end

--creates default sprite
function makespr()
	local sprite={}
	sprite.x=0
	sprite.y=0
	sprite.sx=0
	sprite.sy=0
	sprite.flash=0
	sprite.shake=0
	sprite.frame=1
	sprite.spr=0
	sprite.width=1
	sprite.height=1
	sprite.w=8
	sprite.h=8
 
 	return sprite
end

--function for screen shake
function do_shake()
	local shake_x=rnd(shake)-(shake/2)
	local shake_y=rnd(shake)-(shake/2)
	
	camera(shake_x,shake_y)
	
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
	cls(3)
	draw_graveyard()
	draw_floats()
	draw_pickups()
 	draw_creature()
 	draw_ghost()
	draw_bullet()
	muzzle_flash()
	shockwave()
	draw_explosions()
	draw_creature_bullets()
	draw_score()
	draw_lives()
	draw_bombs()
	draw_ghost_mode()
end

--draws start screen - called when mode is set to "start"
function draw_start()
	cls(3)
	draw_graveyard()
	center_print("creature kills!",64,40,8)
	center_print("press ❎ to start",64,80,blink())
end

--draws game over screen - called when mode is set to "over"
function draw_over()
	draw_game()
	center_print("r.i.p.",64,40,8)
	--timer formatting logic
	if timer_seconds<10 then
		center_print(timer_minutes..":0"..timer_seconds,64,49,blink())
	else
		center_print(timer_minutes..":"..timer_seconds,64,49,blink())
	end
	center_print("press ❎ to continue",64,80,blink())
end

--[[ draws win screen - called
when mode is set to "win" ]]--
function draw_win()
	draw_game()
	center_print("the horde is gone...for now",64,40,8)
	--timer formatting logic
	if timer_seconds<10 then
		center_print(timer_minutes..":0"..timer_seconds,64,49,8)
	else
		center_print(timer_minutes..":"..timer_seconds,64,49,8)
	end	
	center_print("press ❎ to continue",64,80,blink())
end

--draws wave text shown at beginning of each wave
function draw_wavetext()
	draw_game()
	center_print("wave "..wave,64,40,blink())
	--timer formatting logic
	if timer_seconds<10 then
		center_print(timer_minutes..":0"..timer_seconds,64,49,blink())
	else
		center_print(timer_minutes..":"..timer_seconds,64,49,blink())
	end	
end

--draws background assets
function draw_graveyard()
	for i=1,#sprtable do
 	spr(grave_types[i],sprtable[i].x,sprtable[i].y)
	end
end

--draws floating text messages and deletes them after timeout period
function draw_floats()
	for float in all(floats) do
		local col=7
		if t%4<2 then
			col=8
		end
		center_print(float.txt,float.x,float.y,col)
		float.y-=0.5
		float.age+=1
		if float.age>60 then
			del(floats,float)
		end
	end
	floater_timeout-=1
end

--draws player character ghost
function draw_ghost()
	if lives>0 then
		if invul<=0 then
			draw_spr(ghost)
		else
		--flashing effect during invulnerability, etc.
			if sin(t/5)<0.1 then
				draw_spr(ghost)
			end
		end
	end
end

--draws pickups w/ outline and color effect to make them stand out from creatures and projectiles
function draw_pickups()
	for pickup in all(pickups) do
		local col=7
		if t%4<1 then
			col=14
		end
		for i=1,15 do
			pal(i,col)
		end
		draw_outline(pickup)
		for i=1,15 do
			pal(i,i)
		end
		draw_spr(pickup)
	end
end

--draws enemy creatures and flash effect upon being hit
function draw_creature()
	for creature in all(creatures) do
		if creature.flash>0 then
			if t%4<2 then
				pal(4,8)
				pal(9,14)
			end
			
			--boss creature sprite changes when hit and flashes
			if creature.boss==true then
				creature.spr=200
				creature.flash-=1
			else
				creature.flash-=1
				for i=0,15 do
					pal(i,7)
				end
			end
		end
		draw_spr(creature)
		pal()
		set_transparency()
	end
end

--draws bullet
function draw_bullet()
	for new_bullet in all(bullets) do
		draw_spr(new_bullet)
	end
end

--handles muzzle flash animation
function muzzle_flash()
	if muzzle>0 then
		circfill(ghost.x+3,ghost.y,muzzle,11)
		circfill(ghost.x+4,ghost.y,muzzle,11)
	end
end

--draws shockwaves when creatures explode or are hit by bullets and deletes shockwaves once they hit a certain size
function shockwave()
	for shockwave in all(shockwaves) do
		circ(shockwave.x,shockwave.y,shockwave.size,shockwave.col)
		shockwave.size+=shockwave.speed
		if shockwave.size>shockwave.maxsize do
			del(shockwaves,shockwave)
		end
	end
end

--used to draw explosions upon creature death
function draw_explosions()
	for explosion in all(explosions) do
	--explosion color is initially white
		local pc=7
		
		if explosion.green then
		--explosion color is green, used when ghost is hit
			pc=11
		else
		--explosion color uses variety of colors based on age, used when creatures are killed
			pc=particle_age_red(explosion.age)
		end
		
		if explosion.spark then
		--spark effect used when creature is hit
			pset(explosion.x,explosion.y,11)
		else
		--explosion effect used when creature is killed
			circfill(explosion.x,explosion.y,explosion.size,pc)
		end
		
		--explosion formatting
		explosion.x+=explosion.explosion_speed_x
		explosion.y+=explosion.explosion_speed_y
		explosion.explosion_speed_x=explosion.explosion_speed_x*0.85
		explosion.explosion_speed_y=explosion.explosion_speed_y*0.85
		explosion.age=explosion.age+1
		
		--deletes explosion once a certain max age is exceeded
		if explosion.age>explosion.maxage then
			explosion.size=explosion.size-0.5
			if explosion.size<0 then
				del(explosions,explosion)
			end
		end
	end
end

--draws bullets fired by creatures
function draw_creature_bullets()
	for creature_bullet in all(creature_bullets) do
		draw_spr(creature_bullet)
	end
end

--draws score
function draw_score()
	print("score:"..score,51,1,8)
end

--draws lives ui
function draw_lives()
	for i=1,4 do
		if lives>=i then
			spr(7,i*9-8,1)
		end
	end
end

--draws bombs (candy) ui
function draw_bombs()
	spr(bombs_sprite,108,0)
	print(bombs,118,1,14)
end

--[[ ghost mode indicator in
bottom left ]]--
function draw_ghost_mode()
	if ghost_mode_timer>0 then
		if ghost_mode_timer>=90 then
		--full energy
			cells=4
		elseif ghost_mode_timer<90 and ghost_mode_timer>=60 then
		--3/4 energy
			cells=3
		elseif ghost_mode_timer<60 and ghost_mode_timer>=30 then
		--1/2 energy
			cells=2
		elseif ghost_mode_timer<30 and ghost_mode_timer>=0 then
		--1/4 energy
			cells=1
		else
		--depleted energy
			cells=0
		end
		
		--draws ghost mode ui based on number of cells
		for i=1,cells do
			if cells==4 then
				spr(35,-7+i*8,121)
			end
			if cells==3 then
				for i=1,cells do
					spr(35,-7+i*8,121)
					spr(36,25,121)
				end
			end
			if cells==2 then
				for i=1,cells do
					spr(35,-7+i*8,121)
					spr(36,17,121)
					spr(36,25,121)
				end
			end
			if cells==1 then
				for i=1,cells do
					spr(35,-7+i*8,121)
					spr(36,9,121)
					spr(36,17,121)
					spr(36,25,121)
				end
			end
		end
	else
		for i=1,4 do
			spr(36,-7+i*8,121)
		end
	end
end

--initialization

--called to enter "start" state
function start_screen()
	mode="start"
end

--called to start gameplay
function start_game()
	--calls function to adjust default transparency
	set_transparency()
	
	--kill existing music and play game music
	music(-1)
	music(6)
	--sets wave number
	wave=0
	--sets game timer
	timer_frames=0
	timer_seconds=0
	timer_minutes=0
	
	--begins wave 1
	next_wave()
	
	--ghost player character (pc) object	
	ghost=makespr()
	ghost.spr=2
	ghost.x=64
	ghost.y=64
 	ghost.xspeed=0
 	ghost.yspeed=0
 
	--bullet age for despawning
	bullet_timer=0
 
 	--muzzle flash value
 	muzzle=0
 
 	--ui variables
 	score=0
	--max lives versus current lives
 	max_lives=4
 	lives=4
	--bombs (candy)
 	bombs=0
	
	--randomizes bomb (candy) sprite for UI
 	bombs_sprites={52,53,54}
 	bombs_sprite=rnd(bombs_sprites)
 
 	--attack frequency
 	freq=60
 	next_fire=0
 
 	--helper var for invulnerability of ghost pc
 	invul=0
 
 	--background sprites list and functions
 	grave_sprites={10,11,12}
 	grave_types={}
 	sprtable=randpos()
 	graveyard_gen()
 
 	--bullets object
 	bullets={}
 	creature_bullets={}
 
	--creature object
 	creatures={}
 
 	--particle object
 	explosions={}
 
 	--shockwave obj
 	shockwaves={}
 
 	--sets frames to 0 at start
 	t=0
		
	--sets ghost mode timer to max at game start
 	ghost_mode_timer=90
		
	--sets default timeout for floating text messages
 	floater_timeout=60
end

--removes transparency from black(0) and adds to pink(14) instead
function set_transparency()
	palt(0, false)
	palt(14, true)
end

--generates random positions for background graves
function randpos()
  local ids={}
  for i=0,8*8 do
    add(ids,i)
  end

  local picknum=40
  local result={}

  for i=1,picknum do
    local id=del(ids,rnd(ids))
    add(result,id)
  end

  for i,v in pairs(result) do
    result[i]={
      x=v%8*16,y=v\8*16
    }
  end
  
  return result
end

--selects random grave sprites to appear
function graveyard_gen()
	for i=1,#sprtable do
		grave_types[i]=rnd(grave_sprites)
	end
end

--makes start/over screen text blink red
function blink()
	local anim={0,0,0,0,0,0,0,0,0,0,0,0,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8}
	if blinkt>#anim then
		blinkt=0
	end
	return anim[blinkt]
end

--draws outline for sprites to make them standout - used for pickups
function draw_outline(sp)
	spr(sp.spr,sp.x+1,sp.y,sp.width,sp.height)
	spr(sp.spr,sp.x-1,sp.y,sp.width,sp.height)
	spr(sp.spr,sp.x,sp.y+1,sp.width,sp.height)
	spr(sp.spr,sp.x,sp.y-1,sp.width,sp.height)
end

--function to draw all  sprite objects
function draw_spr(sp)
	local sprx=sp.x
	local spry=sp.y
	--shake effect
	if sp.shake>0 then
		sp.shake-=1
		
		if t%4<2 then
			sprx+=1
		end	
	end
	
	if sp.bulletmode==true then
		sprx+=1
		spry-=1
	end
	
	if sp.sx<0 then
		spr(sp.spr,sprx,spry,sp.width,sp.height,true)
	else
		spr(sp.spr,sprx,spry,sp.width,sp.height)
	end
end

--collision detection
function collision(a,b)
	local a_left=a.x
	local a_top=a.y
	local a_right=a.x+a.w-1
	local a_bottom=a.y+a.h-1
		
	local b_left=b.x
	local b_top=b.y
	local b_right=b.x+a.w-1
	local b_bottom=b.y+a.h-1
		
	if a_top > b_bottom then
		return false
	end
	if b_top > a_bottom then
		return false
	end
	if a_left > b_right then
		return false
	end
	if b_left > a_right then
		return false
	end
		
	return true
end

--creates creature obj and and adds it to list
function spawn_creature(creature_type,x,y,wait)
	--creature defaults
	local creature=makespr()
 	creature.x=x*2-64
 	creature.y=y-66
 
 	creature.posx=x
 	creature.posy=y
 
	creature.direction=0
 
 	creature.anispeed=0.5
 
 	creature.type=creature_type
 
 	creature.wait=wait
 
 	creature.mission="fly_in"
 
 	if creature_type==nil or creature_type==1 then
 	--frank
 		creature.spr=26
 		creature.hp=3
 		creature.animation={26,26,27,27}
 		creature.anispeed=0.1
 		creature.has_fired=false
 	elseif creature_type==2 then
 	--witch
 		creature.spr=22
 		creature.hp=2
 		creature.animation={22,23}
 		creature.anispeed=0.1
 		creature.has_fired=false
 elseif creature_type==3 then
 	--vampire
 		creature.spr=13
 		creature.hp=4
 		creature.animation={13,14,15}
 		creature.anispeed=0.1
 		creature.has_fired=false
 elseif creature_type==4 then
 	--ufo
 		creature.spr=64
 		creature.hp=20
 		creature.animation={64,66,68,70,72,76,78,96}
 		creature.anispeed=1
 		creature.has_fired=false
 		creature.width=2
 		creature.height=2
 		creature.w=16
 		creature.h=16
 elseif creature_type==5  then
 	--boss
		creature.spr=196
 		creature.hp=100
 		creature.animation={196}
 		creature.anispeed=1
 		creature.has_fired=false
 		creature.width=4
 		creature.height=4
 		creature.w=32
 		creature.h=32
 	
 		creature.x=48
 		creature.y=-32
 
 		creature.posx=48
 		creature.posy=25
 	
	 	creature.boss=true
 	end
 
 	add(creatures, creature)
end

--creates particle obj and adds it to list
function spawn_explosion(exp_x,exp_y,isgreen)
	local explosion={}
	explosion.x=exp_x
	explosion.y=exp_y
	explosion.explosion_speed_x=0
	explosion.explosion_speed_y=0
	explosion.age=0
	explosion.size=10
	explosion.maxage=0
	explosion.green=isgreen

	add(explosions,explosion)
	
	for i=1,3 do
		local explosion={}
		explosion.x=exp_x
	 	explosion.y=exp_y
		explosion.explosion_speed_x=(rnd()-0.5)*6
		explosion.explosion_speed_y=(rnd()-0.5)*6
		explosion.age=rnd(2)
		explosion.size=1+rnd(4)
		explosion.maxage=10+rnd(10)
		explosion.green=isgreen
		
		add(explosions,explosion)
	end
end

--function to change color of particle based on age
function particle_age_red(particle_age)
	local col=7
	
	if particle_age>5 then
		col=6
	end
	if particle_age>7 then
		col=13
	end
	if particle_age>12 then
		col=2
	end
	if particle_age>15 then
		col=5
	end
	
	return col
end

--function to create shockwave upon bullet/enemy collision
function make_small_wave(wave_x,wave_y,wave_col)
	if wave_col==nil then
		wave_col=11
	end
	local shockwave={}
	shockwave.x=wave_x
	shockwave.y=wave_y
	shockwave.size=3
	shockwave.maxsize=5
	shockwave.col=wave_col
	shockwave.speed=1
	add(shockwaves,shockwave)
end

--function to create shockwave upon enemy explosion
function make_big_wave(wave_x,wave_y)
	local shockwave={}
	shockwave.x=wave_x
	shockwave.y=wave_y
	shockwave.size=3.5
	shockwave.maxsize=20
	shockwave.col=6
	shockwave.speed=3
	add(shockwaves,shockwave)
end

--makes bullet collision particle effect for creatures
function make_slime(hit_x,hit_y)
	local explosion={}
	explosion.x=hit_x
	explosion.y=hit_y
	explosion.explosion_speed_x=(rnd()-0.5)*8
	explosion.explosion_speed_y=(rnd()-1)*3
	explosion.age=rnd(2)
	explosion.size=1+rnd(4)
	explosion.maxage=10+rnd(10)
	explosion.green=isgreen
	explosion.spark=true
		
	add(explosions,explosion)
end

--function to show floating text messages
function show_float(fltxt,flx,fly)
	local float={}
	float.x=flx
	float.y=fly
	float.txt=fltxt
	float.age=0
	
	add(floats,float)
end

--function to show floating text messages based on button input
function show_btn_float(fltxt,flx,fly)
	local float={}
	float.x=flx
	float.y=fly
	float.txt=fltxt
	float.age=0
	
	--control sfx and float display state based on timeout
	if floater_timeout<=0 then
		sfx(13)
		add(floats,float)
		floater_timeout=60
	end
end

--center print text
function center_print(txt,x,y,c)
	print(txt,x-#txt*2,y,c)
end

--waves and enemies

--spawns waves and according to creature type
--1 = frank
--2 = witch
--3 = drac
--4 = ufo
--5 = jack (boss)
function spawn_wave()
	if wave==1 then
		freq=60
		place_creatures({
			{0,1,1,1,1,1,1,1,1,0},
			{0,1,1,1,1,1,1,1,1,0},
			{0,1,1,1,1,1,1,1,1,0},
			{0,1,1,1,1,1,1,1,1,0}
		})		
	elseif wave==2 then
		freq=60
		place_creatures({
			{0,2,2,2,2,2,2,2,2,0},
			{0,2,2,2,2,2,2,2,2,0},
			{0,2,2,2,2,2,2,2,2,0},
			{0,2,2,2,2,2,2,2,2,0}
		})
	elseif wave==3 then
		freq=60
		place_creatures({
			{1,1,2,2,1,1,2,2,1,1},
			{1,1,2,2,2,2,2,2,1,1},
			{2,2,2,2,2,2,2,2,2,2},
			{2,2,2,2,2,2,2,2,2,2}		
	})
	elseif wave==4 then
		freq=60
		place_creatures({
			{0,3,3,3,3,3,3,3,3,0},
			{0,3,3,3,3,3,3,3,3,0},
			{0,3,3,3,3,3,3,3,3,0},
			{0,3,3,3,3,3,3,3,3,0}
		})
	elseif wave==5 then
		freq=60
		place_creatures({
			{3,3,0,1,1,1,1,0,3,3},
			{3,3,0,1,1,1,1,0,3,3},
			{3,3,0,1,1,1,1,0,3,3},
			{3,3,0,1,1,1,1,0,3,3}		
	})
	elseif wave==6 then
		freq=60
		place_creatures({
			{0,1,2,2,1,1,2,2,1,0},
			{3,1,2,2,1,1,2,2,1,3},
			{3,1,2,2,2,2,2,2,1,3},
			{0,1,2,2,2,2,2,2,1,0}		
	})
	elseif wave==7 then
		freq=60
		place_creatures({
			{3,1,3,1,2,2,1,3,1,3},
			{1,3,1,2,1,1,2,1,3,1},
			{3,1,3,1,2,2,1,3,1,3},
			{1,3,1,2,1,1,2,1,3,1}		
	})
	elseif wave==8 then
		freq=60
		place_creatures({
			{1,1,1,0,4,0,0,1,1,1},
			{1,1,0,0,0,0,0,0,1,1},
			{1,1,0,1,1,1,1,0,1,1},
			{1,1,0,1,1,1,1,0,1,1}		
	})
	elseif wave==9 then
		freq=60
		place_creatures({
			{3,3,0,1,1,1,1,0,3,3},
			{4,0,0,2,2,2,2,0,4,0},
			{0,0,0,2,1,1,2,0,0,0},
			{1,1,0,1,1,1,1,0,1,1}		
	})
	elseif wave==10 then
		freq=60
		place_creatures({
			{0,0,1,1,1,1,1,1,0,0},
			{3,3,1,1,1,1,1,1,3,3},
			{3,3,2,2,2,2,2,2,3,3},
			{3,3,2,2,2,2,2,2,3,3}		
	})
	elseif (wave==11) then
		--boss wave
		freq=60
		place_creatures({
			{0,0,0,0,5,0,0,0,0,0},
			{0,0,0,0,0,0,0,0,0,0},
			{0,0,0,0,0,0,0,0,0,0},
			{0,0,0,0,0,0,0,0,0,0}
		})
	end
end

--handles creature placement
function place_creatures(lvl)
	for y=1,4 do
		local y_line=lvl[y]
		for x=1,10 do
			if y_line[x]!=0 do
				sfx(7)
				spawn_creature(y_line[x],x*12-6,4+y*12,x*4)
			end
		end
	end
end

--increments wave and checks if game has completed
function next_wave()
	wave+=1
	sfx_check=0
	is_holding=false
	
	if wave>11 then
		mode="win"
		lockout=t+30
		music(0)
	else
		mode="wavetext"
		--slight adjustment to wavetime for wave 1 to account for sfx
		if wave==1 then
			wavetime=110
		else
			wavetime=80
		end
		--changes sfx after wave 1
		if wave>1 then
			sfx(6)
		end
	end
end

--behaviors

--defines what creatures will be doing based on mission
function creature_do(creature)
	if creature.wait>0 then
		creature.wait-=1
		return
	end
	
	if creature.mission=="fly_in" then
	--moving to position
		
		local dx=(creature.posx-creature.x)/7
		local dy=(creature.posy-creature.y)/7
		
		if creature.boss then
			dx=min(dx, 1.5)
			dy=min(dy, 1.5)
		end

		creature.x+=dx
		creature.y+=dy

		if abs(creature.y-creature.posy)<0.7 then
			creature.y=creature.posy
			creature.mission="hover"
			if creature.boss==true then
				--boss mission 1
				creature.mission="boss_1"
			else
				--other creatures hover
				creature.mission="hover"	
			end
		end
	
	elseif creature.mission=="hover" then
	--staying put
	elseif creature.mission=="boss_1" then
		if t%15==0 then
			fire(creature,0,2)
		end
	--boss missions:
	elseif creature.mission=="boss_2" then
	
	elseif creature.mission=="boss_3" then
	
	elseif creature.mission=="boss_4" then
	
	elseif creature.mission=="boss_5" then
	
	elseif creature.mission=="attack" then
	--attacking ghost by flying down
		if creature.type==1 then
			--frank
			creature.sy=1
			if creature.has_fired==true then
				--since frank has fired, he attacks by moving left and right and directly down
				creature.sx=sin(t/45)
			else
			--since frank has not fired, he attacks by moving towards and pursuing ghost
				ang=atan2(ghost.y-creature.y,ghost.x-creature.x)
				--if frank is below ghost, he moves directly down
				if creature.y>ghost.y then
					creature.sy=1
					creature.sx=0
				else
				--if ghost is in ghost mode or invulnerable, frank will not pursue and will move directly down
					if invul<=0 and ghost.mode!=1 then
						move_ang(creature,ang,1)
					else
						creature.sy=1
						creature.sx=0
					end	
				end
			end
			
			--minute adjustments to frank's movement to trend toward screen center
			if creature.x<32 then
					creature.sx+=1-(creature.x/32)
			end
			if creature.x>88 then
				creature.sx-=(creature.x-88)/32
			end
			
		elseif creature.type==2 then
			--witch
			creature.sy=2.5
			creature.sx=sin(t/20)
			--minute adjustments to witch's movement to trend toward screen center
			if creature.x<32 then
					creature.sx+=1-(creature.x/32)
			end
			if creature.x>88 then
				creature.sx-=(creature.x-88)/32
			end
		elseif creature.type==3 then
		--drac
			if creature.sx==0 then
			--flying down
				creature.sy=2
				if ghost.y<=creature.y then
					--stops moving down once ghost and vampire y values are equal
					creature.sy=0
					if ghost.x<creature.x then
					--if ghost is to the left of vampire, vampire moves left
						creature.sx=-2
					else
					--if ghost is to the right of vampire, vampire moves right
						creature.sx=2
					end
				end
		end			
		elseif creature.type==4 then
		--ufo
			--speed changes based on y position
			creature.sy=0.3
			if creature.y>110 then
				creature.sy=1
			else
			--spreadshot based on mod t interval
				if t%30==0 then
					spreadshot(creature,8,1.3,rnd())
				end
			end
		end
		move(creature)
	end
end

--picks creature from list and sets it to attack
function picking()
	if mode!="game" then
		return
	end
	
	if t>next_fire then
		pick_fire()
		next_fire=t+20+rnd(20)
	end
	
	if t%freq==0 then
		pick_attack()
	end
end

--picks a creature to fly down and attack ghost
function pick_attack()
	local maxnum=min(10, #creatures)
	local index=flr(rnd(maxnum))
	local index=#creatures-index
		
	local creature=creatures[index]
	
	if creature==nil then return end
	
	if creature.mission=="hover" then
		creature.mission="attack"
			
		--adjusts drac sprite animation based on hp 
		if creature.type==3 then
			creature.anispeed=0.5
			if creature.hp>=3 then
				creature.animation={19,20,21}
			else
				creature.animation={37,38,39}
			end			
		end
		
		creature.wait=30
		creature.shake=30
	end
end

--picks a creature to shoot at ghost
function pick_fire()
	local maxnum=min(10, #creatures)
	local index=flr(rnd(maxnum))
	local index=#creatures-index
	
	for creature in all (creatures) do
	--spreadshot if creature is a ufo
		if creature.type==4 and creature.mission=="hover" then
			if rnd()<0.5 then
				spreadshot(creature,12,1.3,rnd())
				return
			end
		end
	end
	
	local creature=creatures[index]
	
	--drac does not fire a projectile
	if creature==nil or creature.type==3 then return end
		
	if creature.mission=="hover" then
		if creature.type==4 then
		--ufo
			spreadshot(creature,12,1.3,rnd())
		elseif creature.type==5 then
		--jack (boss)
			fire(creature,0,2)
		elseif creature.type==2 then
		--witch
			--witches fire a projectile at ghost - if ghost is not in ghost mode fire aimed projectile
			if ghost.mode!=1 then
				aimedfire(creature,2)
			else
				fire(creature,0,2)
			end
		elseif creature.type==1 then
		--frank
			--frank fires a projectile at ghost - if frank has not fired yet, his sprite and animation will be updated based on hp 
			if creature.has_fired==false then
				if creature.hp>=3 then
					creature.spr=47
					creature.animation={47,47,48,48}
				else
					creature.spr=49
					creature.animation={49,49,50,50}
				end
			end
			fire(creature,0,2)
		end
	end
end

--function to move object
function move(obj)
	obj.x+=obj.sx
	obj.y+=obj.sy
end

--called when creature hp is equal to or less than 0
function kill_creature(creature)
	del(creatures,creature)
	sfx(2)
	score=score+1
	spawn_explosion(creature.x+4,creature.y+4,false)
	make_big_wave(creature.x+4,creature.y+4)
	
	local pickup_chance=0.1
	
	if creature.mission=="attack" then
	--if creature was attacking, it has a higher chance to drop pickup
		if rnd()<0.5 then
			pick_attack()
		end
		show_float("busted!",creature.x+4,creature.y+4)
		pickup_chance=0.2
	end
	
	--drop pickup based on chance
	if rnd()<pickup_chance then
		drop(creature.x,creature.y)
	end
end

--spawns pickup
function drop(px,py)
	local pickup=makespr()
	pickup.x=px
	pickup.y=py
	pickup.sy=.75
	pickup.spr=rnd(bombs_sprites)
	add(pickups,pickup)
end

--pickup logic
function pickup_logic(pickup)
	bombs+=1
	--make small wave where pickup was collected
	make_small_wave(pickup.x+4,pickup.y+4,14)

	--if player collects 11 bombs (candies):
	if bombs>=10 then
	--if the players lives are less than max lives:
		if lives<max_lives then
		--bombs reset to 0
			bombs=0
			--lives increase by 1
			lives+=1
			sfx(12)
			show_float("ghoulish!",pickup.x+4,pickup.y+4)
		--if the players lives are equal to max lives:
		else
		--if ghost mode is less than max:
			if ghost_mode_timer<90 then
				--bombs reset to 0
				bombs=0
				--ghost mode timer resets to max
				ghost_mode_timer=90
				show_float("energy restored!",pickup.x+4,pickup.y+4)
				sfx(15)
			--if both lives and ghost mode are max:
			else
				sfx(11)
				show_float("2x score multiplier!",pickup.x+4,pickup.y+4)	
			end
		end
	--if player collects 6-10 bombs (candies):
	elseif bombs>=5 then
		--if ghost mode timer is less than half:
		if	ghost_mode_timer<45 then
		--ghost mode timer increased to half
			ghost_mode_timer=45
			show_float("energy restored!",pickup.x+4,pickup.y+4)
			sfx(15)
		else
		--if ghost mode timer is more than half:
			sfx(11)
			show_float("100",pickup.x+4,pickup.y+4)	
		end
	else
		sfx(11)			
	end
end

-- animation function - code was originally written for creatures, but has been repurposed for all sprites
function animate(creature)
	creature.frame+=creature.anispeed
	
	if flr(creature.frame)>#creature.animation then
			creature.frame=1
	end
	
	creature.spr=creature.animation[flr(creature.frame)]
end

--bullets

--called when creature  mission is "fire" - shoots projectile at ghost
function fire(creature,ang,spd)
	sfx(10)
	local creature_bullet=makespr()
	creature_bullet.x=creature.x-1
	creature_bullet.y=creature.y
	
	--adjust spawn location of fired creature bullets for ufo and boss
	if creature.type==4 then
		creature_bullet.x=creature.x+4
		creature_bullet.y=creature.y+12
	elseif creature.boss then
		creature_bullet.x=creature.x+11
		creature_bullet.y=creature.y+22
	end
	
	--adjusts creature bullet sprite based on creature type
	if creature.type==4 then
		--ufo
		creature_bullet.spr=43
		creature_bullet.animation={43,44,45,44,43}
		creature_bullet.anispeed=1
	elseif creature.type==1 then
	--frank
		creature_bullet.anispeed=1
		--frank has not fired yet
		if creature.has_fired==false then
		--frank has taken damage
			if creature.hp<3 then
			--sprite is set to slimed frank head
				creature_bullet.spr=51
				creature_bullet.animation={51,51}
			--frank has not taken damage
			else
			--sprite is set to normal frank head
				creature_bullet.spr=46
				creature_bullet.animation={46,46}
			end
		--frank has fired
		else
		--sprite is set to random sprite from frank_bullets list
			frank_bullets={55,56,60}
			creature_bullet.spr=rnd(frank_bullets)
			--adjust animation based on sprite
			if creature_bullet.spr==55 then
				creature_bullet.animation={55,55}
			elseif creature_bullet.spr==56 then
				creature_bullet.animation={56,56,57,57,58,58,59,59}
			else	
				creature_bullet.animation={60,60,61,61,62,62,63,63}
			end	
		end
	--frank can only throw head once
	creature.has_fired=true	
	elseif creature.type==2 then
	--witch
	--blue potion (spr148) potion saps ghost mode energy, so it should only be available if ghost mode is not already depleted
		if ghost_mode_timer>0 then
			potion_sprites={40,132,148}
		else 
			potion_sprites={40,132}
		end
		--sprite is set to random sprite from potion_sprites list
		creature_bullet.spr=rnd(potion_sprites)
		--adjust animation based on sprite
		if creature_bullet.spr==132 then
			creature_bullet.animation={132,133,134}
		elseif creature_bullet.spr==148 then
			creature_bullet.animation={148,149,150}
		else
			creature_bullet.animation={40,41,42}
		end
		creature_bullet.anispeed=0.1
	else
	--jack (boss)
		creature_bullet.spr=9
		creature_bullet.animation={9,9}
		creature_bullet.anispeed=0.1
	end

	creature_bullet.sy=cos(ang)*spd
	creature_bullet.sx=sin(ang)*spd
	creature_bullet.w=5
	creature_bullet.h=5
	creature_bullet.bulletmode=true
	
	creature_bullet.frank_head=false
	
	--the first time frank fires, the projectile will be a frank head
	if creature.type==1 and creature.has_fired==false then
		creature_bullet.frank_head=true
	end
	
	add(creature_bullets,creature_bullet)
	
	return creature_bullet
end

--ufo spreadshot
function spreadshot(creature,num,spd,base)
	if base==nil then
		base=0
	end
	for i=1,num do
		fire(creature,1/num*i+base,spd)
	end
end

--witches projectile - targeted at ghost
function aimedfire(creature,spd)
	local creature_bullet=fire(creature,0,spd)
	
	local ang=atan2((ghost.y+4)-creature_bullet.y,(ghost.x+4)-creature_bullet.x)
	
	creature_bullet.sy=cos(ang)*spd
	creature_bullet.sx=sin(ang)*spd
end

--function to move creature toward ghost
function move_ang(creature,ang,spd)
	creature.sy=cos(ang)*spd
	creature.sx=sin(ang)*spd
end

--called when player presses fire button while in ghost mode and has bombs (candies)
function ghost_bomb()
	floater_timeout=60
	sfx(14)
	local spacing=0.25/(bombs*2)
	
	for i=0,bombs*2 do
		local ang=0.375+spacing*i
		
		local new_bullet=makespr()
		new_bullet.x=ghost.x
		new_bullet.y=ghost.y-3
		new_bullet.spr=8
		new_bullet.dmg=3
		
		new_bullet.sy=cos(ang)*4
		new_bullet.sx=sin(ang)*4
	
		add(bullets,new_bullet)
	end
	
	make_big_wave(ghost.x+3,ghost.y+3)
	shake=5
	muzzle=5
	invul=30
end