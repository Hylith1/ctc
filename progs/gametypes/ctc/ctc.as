/**
 * 2010-2012 Seeming
 * A big thanks to Hylith trxxrt and Zaran for their help and their support !
 * 2015 updated by Hylith for Warsow 1.51
 * 2019 updated by Hylith for Warfork
 * @file ctc.as
 * Main file of the CTC gametype
 * based on the "flag's code" of "The Runner" by DrahtMaul
 */

 // variables <int>
int prcYesIcon;
int prcShockIcon;
int prcShellIcon;
int prcChickenIcon;
int prcCarrierIcon;
int modelChickenhand;
int prcAnnouncerChickenTaken;
int prcAnnouncerChickenDrop;
int prcAnnouncerPhilippe;
int prcAnnouncerPrecoce;
int prcAnnouncerPatron;
int announcesNumber = 0;
bool showMessageOfScorelimitPerRun = true;
uint lastAnnounceTime = 0;
uint antiSimultaneousAnnounces = 0;

// constantes
const String C_GAMETYPE_AUTHOR = "Seeming & Hylith";
const String C_GAMETYPE_VERSION = "2.00";
const String C_GAMETYPE_NAME = "Catch the chicken";
const int MAX_SCORE_PER_RUN = 10; // anti "run forever". set to a big value like 100000 to disable this feature
const int MAX_NB_ANNOUNCER_ALLOWED = 5; // max number of crap sounds before we consider it is spam
const uint NB_ANNOUNCER_TIMEOUT = 10000; // timeout of spam protection (in ms)
const int RUN_SCOREINTERVAL = 3000; // interval between scoring (ie 1 point each 3 seconds) (in ms)
const int RUN_SCOREINTERVAL_DEBUFF = 6000; // interval between scoring (ie 1 point each 6 seconds when you overpass "anti run forever") (in ms)
const float chickenDropDistance = 2.5;

// Cvars
Cvar dmAllowPickup( "dm_allowPickup", "1", CVAR_ARCHIVE );
Cvar dmAllowPowerups( "dm_allowPowerups", "1", CVAR_ARCHIVE );
Cvar dmAllowPowerupDrop( "dm_powerupDrop", "1", CVAR_ARCHIVE );

Chicken chicken;

void CTC_playerKilled( Entity @target, Entity @attacker, Entity @inflicter ){
    if ( @target.client == null )
        return;

	if ( @target == @chicken.carrier )
        chicken.dropChicken();
	
    // drop items
    if ( ( G_PointContents( target.origin ) & CONTENTS_NODROP ) == 0 )
    {
        // drop the weapon
        if ( target.client.weapon > WEAP_GUNBLADE )
        {
            GENERIC_DropCurrentWeapon( target.client, true );
        }

        // drop ammo pack (won't drop anything if player doesn't have any ammo)
        target.dropItem( AMMO_PACK_WEAK );

        if ( dmAllowPowerupDrop.boolean )
        {
            if ( target.client.inventoryCount( POWERUP_QUAD ) > 0 )
            {
                target.dropItem( POWERUP_QUAD );
                target.client.inventorySetCount( POWERUP_QUAD, 0 );
            }

            if ( target.client.inventoryCount( POWERUP_SHELL ) > 0 )
            {
                target.dropItem( POWERUP_SHELL );
                target.client.inventorySetCount( POWERUP_SHELL, 0 );
            }
        }
    }
}

void chicken_touch( Entity @ent, Entity @other, const Vec3 planeNormal, int surfchickens ){
    if ( @other == null || @other.client == null )
        return;

    if ( chicken.dropper == other.playerNum && chicken.droppedTime > levelTime )
        return;

    chicken.setCarrier( other );
}

void chicken_die( Entity @ent, Entity @inflicter, Entity @attacker ){
    chicken.spawn();
}

void chicken_think( Entity @ent ){
        chicken.spawn();
}

class Chicken{
    Entity @carrier;
    Entity @chicken;
    Entity @spawnpoint;
    uint nextScore;
    int dropper;
    int currentScoreOfRunner;
    uint droppedTime;
    int carrierTeam;
    Vec3[] Spawn_Locations;

    Chicken(){
        @this.carrier = null;
        @this.chicken = null;
        this.nextScore = 0;
        this.currentScoreOfRunner = 0;
        this.dropper = -1;
        this.droppedTime = 0;
        this.carrierTeam = -1;
    }

    ~Chicken(){
	}

    void spawn(){
        //Entity @point = @GENERIC_SelectBestRandomSpawnPoint( null, "info_player_deathmatch" );
        //@this.spawnpoint = @point;
        this.FindSpawns("info_player_deathmatch");
        Vec3 spawnlocation = this.ChooseSpawn();
        @this.carrier = null;
        //@this.spawnpoint = spawnlocation;
        this.chicken_spawn(spawnlocation);
    }

    // ChooseSpawn & FindSpawns Functions are stolen to the arcade gametype, thanks it fixed a spawn bug on warfork
    Vec3 ChooseSpawn()
    {
        int chosenPoint;

        chosenPoint = int(brandom(0, this.Spawn_Locations.length - 0.001f)); // it has to be less than the length

        return this.Spawn_Locations[chosenPoint];
    }

    void FindSpawns(String spawnType)
    {
        array<Entity @>  @spawnEntity; // use this to find possible spawns

        // spawn at a player_deathmatch
        // first i need to know all the player_deathmatch locations. Change their name as you find them until none are left.
        uint i = 0;

        @spawnEntity = @G_FindByClassname( spawnType);

        
        for(i=0; i<spawnEntity.size(); i++){
            this.Spawn_Locations.insertLast(spawnEntity[i].origin);
            
            spawnEntity[i].origin;
            //G_Print("^7"+spawnEntity.get_classname()+"!!\n"); // debug
            spawnEntity[i].set_classname("added_spawnpoint");
        }

        // rename all the info_player_deathmatches back
        @spawnEntity = @G_FindByClassname( "added_spawnpoint");

        for(i=0; i<spawnEntity.size(); i++){
            spawnEntity[i].set_classname(spawnType);
        }
    }

    void chicken_spawn(Vec3 location)
    {
        if ( @this.chicken != null )
        {
            this.chicken.freeEntity();
            @this.chicken = null;
        }
       
        Vec3 tmins(-16,-16,-16);
        Vec3 tmaxs(16, 16, 40);

        Entity @chicken = G_SpawnEntity( "chicken" );
        chicken.team = TEAM_PLAYERS;
        chicken.type = ET_GENERIC;
        chicken.effects |= EF_CARRIER ;
        chicken.setSize( tmins, tmaxs );
        chicken.solid = SOLID_TRIGGER;
        chicken.modelindex = G_ModelIndex("models/ctc/poulet.md3");
        chicken.moveType = MOVETYPE_TOSS;
        chicken.svflags &= ~uint(SVF_NOCLIENT);

        chicken.origin = location;
        chicken.linkEntity();
        AI::AddGoal(chicken);
        @this.chicken = @chicken;
        @this.chicken.touch = chicken_touch;
        @this.chicken.die = chicken_die;
        @this.chicken.think = chicken_think;
    }

    void drop_chick( Entity @point ){
        if ( @this.chicken != null )
        {
            this.chicken.freeEntity();
            @this.chicken = null;
        }

        if ( @point == null )
            return;

        Entity @chicken = G_SpawnEntity( "chicken" );
        Vec3 mins( -16.0, -16.0, -16.0 ), maxs( 16.0, 16.0, 40.0 );

        chicken.team = TEAM_PLAYERS;
        chicken.type = ET_GENERIC;
        chicken.effects |= EF_CARRIER ;
        chicken.setSize( mins, maxs );
        chicken.solid = SOLID_TRIGGER;
        chicken.modelindex = G_ModelIndex("models/ctc/poulet.md3");
        chicken.moveType = MOVETYPE_TOSS;
        chicken.svflags &= ~uint(SVF_NOCLIENT);

        chicken.origin = point.origin;
        chicken.linkEntity();
        AI::AddGoal(chicken);
        @this.chicken = @chicken;
        @this.chicken.touch = chicken_touch;
        @this.chicken.die = chicken_die;
        @this.chicken.think = chicken_think;
    }

    void setCarrier( Entity @carrier ){
        AI::ReachedGoal(chicken);
        this.chicken.freeEntity();
        @this.chicken = null;
        carrier.effects |= EF_CARRIER ;

        @this.spawnpoint = null;
        @this.carrier = @carrier;
        this.carrier.client.inventoryClear();
        this.carrier.client.set_pmoveFeatures( this.carrier.client.pmoveFeatures & ~int(PMFEAT_ITEMPICK) );
        this.carrier.modelindex2 = modelChickenhand;
        this.nextScore = levelTime + RUN_SCOREINTERVAL;
        this.carrier.client.addAward( S_COLOR_GREEN + "KEEP THE CHICKEN!!!" );

        G_AnnouncerSound( null, prcAnnouncerChickenTaken, GS_MAX_TEAMS, true, null );
        if ( this.carrierTeam == -1)
        {
            G_PrintMsg( null, carrier.client.name + " has captured the Chicken !\n" );
        }
        else
        {
            if ( this.carrierTeam == carrier.team )
            {
                G_PrintMsg( null, carrier.client.name + " has secured the Chicken !\n" );
            }
            else
            {
                G_PrintMsg( null, carrier.client.name + " has stolen the Chicken !\n" );
            }
        }
        this.carrierTeam = carrier.client.team;
        
        if ( this.dropper != this.carrier.playerNum )
        {
            this.currentScoreOfRunner = 0;
            showMessageOfScorelimitPerRun = true;
        }
    }

    void dropChicken(){
        this.carrier.effects &= ~uint( EF_CARRIER|EF_FLAG_TRAIL );
        this.carrier.modelindex2 = 0;
        G_AnnouncerSound( null, prcAnnouncerChickenDrop, GS_MAX_TEAMS, true, null );
        G_PrintMsg( null, carrier.client.name + " has dropped the Chicken !\n" );

        if ( ( G_PointContents( this.carrier.origin ) & CONTENTS_NODROP ) == 0 )
        {
            Entity @carrier = @this.carrier;
            this.drop_chick( this.carrier );
            Entity @chicken = this.chicken;
            Trace tr;
            Vec3 end, dir, temp1, temp2;
            Vec3 mins( -16.0, -16.0, -16.0 ), maxs( 16.0, 16.0, 40.0 );
            carrier.angles.angleVectors( dir, temp1, temp2 );
            end = ( carrier.origin + ( 0.5 * ( maxs + mins ) ) ) + ( dir * 24 );

            tr.doTrace( carrier.origin, mins, maxs, end, carrier.entNum, MASK_SOLID );

            chicken.origin = tr.endPos;
            chicken.origin2 = tr.endPos;

            Vec3 player_velocity;
            player_velocity = this.carrier.velocity;
            //dir *= 200;
            //dir.z = 250;

            //G_PrintMsg( null,"dropChicken("+player_velocity.x+","+player_velocity.y+","+player_velocity.z+")\n" );
            chicken.velocity = player_velocity;

            chicken.linkEntity();
        }
        else
            this.spawn();

        chicken.nextThink = levelTime + 15000;
        this.dropper = -1;
        @this.carrier = null;
        @this.chicken = @chicken;

    }

    void passChicken(){
        Entity @carrier = @this.carrier;
        this.carrier.modelindex2 = 0;
        this.carrier.effects &= ~uint( EF_CARRIER );
        this.carrier.client.set_pmoveFeatures( this.carrier.client.pmoveFeatures | int(PMFEAT_ITEMPICK) );  
            if ( gametype.isInstagib )
            {
                        this.carrier.client.inventoryGiveItem( WEAP_INSTAGUN );
                        this.carrier.client.inventorySetCount( AMMO_INSTAS, 1 );
                        this.carrier.client.inventorySetCount( AMMO_WEAK_INSTAS, 1 );
            }
            else
            {
				  this.carrier.client.inventoryGiveItem(WEAP_GUNBLADE);
				  this.carrier.client.inventorySetCount(AMMO_GUNBLADE, 10);
                  if( ! dmAllowPickup.boolean )
                  {
                        Item @item;
                        Item @ammoItem;
                        
                        // give all weapons
                        for ( int i = WEAP_GUNBLADE + 1; i < WEAP_TOTAL; i++ )
                        {
                            if ( i == WEAP_INSTAGUN ) // dont add instagun...
                                continue;

                            this.carrier.client.inventoryGiveItem( i );

                            @item = @G_GetItem( i );

                            @ammoItem = @G_GetItem( item.weakAmmoTag );
                            if ( @ammoItem != null )
                                this.carrier.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

                            @ammoItem = @G_GetItem( item.ammoTag );
                            if ( @ammoItem != null )
                                this.carrier.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );
                        }
                  }
            }

        this.carrier.client.selectWeapon( -1 );
        G_AnnouncerSound( null, prcAnnouncerChickenDrop, GS_MAX_TEAMS, true, null );
        G_PrintMsg( null, carrier.client.name + " has dropped the Chicken !\n" );

        if ( ( G_PointContents( this.carrier.origin ) & CONTENTS_NODROP ) == 0 )
        {

            this.drop_chick( this.carrier );
            Entity @chicken = this.chicken;
            Trace tr;
            Vec3 end, dir, temp1, temp2;
            Vec3 mins( -16.0, -16.0, -16.0 ), maxs( 16.0, 16.0, 40.0 );
            carrier.angles.angleVectors( dir, temp1, temp2 );
            end = ( carrier.origin + ( 0.5 * ( maxs + mins ) ) ) + ( dir * 24 );

            tr.doTrace( carrier.origin, mins, maxs, end, carrier.entNum, MASK_SOLID );

            chicken.origin = tr.endPos;
            chicken.origin2 = tr.endPos;

            Vec3 player_velocity;
            player_velocity = this.carrier.velocity;
            bool no_x = false;
            bool no_y = false;

            if (!((dir.x > 0 && player_velocity.x > 0) || (dir.x < 0 && player_velocity.x < 0))) {
                no_x = true;
            }
            if (!((dir.y > 0 && player_velocity.y > 0) || (dir.y < 0 && player_velocity.y < 0))) {
                no_y = true;
            }

            if (no_y && no_x){
                dir *= 200 * chickenDropDistance;
            }else if (!no_y && !no_x) {
                dir *= 100 * chickenDropDistance;
            }else{
                dir *= 150 * chickenDropDistance;
            }

            if (dir.x > 0 && player_velocity.x > 0){
                dir.x += player_velocity.x;
            }else if (dir.x < 0 && player_velocity.x < 0) {
                dir.x += player_velocity.x;
            }
           
            if (dir.y > 0 && player_velocity.y > 0){
                dir.y += player_velocity.y;
            }else if (dir.y < 0 && player_velocity.y < 0) {
                dir.y += player_velocity.y;
            }

            if (dir.z >= 0){
                if (dir.z < 320){
                    dir.z = 320;
                    if (player_velocity.z > 0){
                    	dir.z += (player_velocity.z * 2 / 3);
	                }
                }
                if(player_velocity.z == 0){
                    dir.z *= 1.5;
                }
            }else if (dir.z < 0){
                if (dir.z > -5){
                    dir.z = 290;
                }else if (dir.z > -10){
                    dir.z = 260;
                }else if (dir.z > -20){
                    dir.z = 230;
                }else if (dir.z > -25){
                    dir.z = 200;
                }else if (dir.z > -31){
                    dir.z = 170;
                }
                if (player_velocity.z < 0) {
                    dir.z += (player_velocity.z * 2 / 3);
                }
            }

            //G_PrintMsg( null,"passChicken("+dir.x+","+dir.y+","+dir.z+")\n" );
            chicken.velocity = dir;

            chicken.linkEntity();
        }
        else
            this.spawn();


        this.dropper = carrier.playerNum;
        this.droppedTime = levelTime + 1000;
        chicken.nextThink = levelTime + 15000;
        @this.carrier = null;
        @this.chicken = @chicken;

    }

    void passChicken2(){
        Entity @carrier = @this.carrier;
        this.carrier.modelindex2 = 0;
        this.carrier.effects &= ~uint( EF_CARRIER );
        this.carrier.client.set_pmoveFeatures( this.carrier.client.pmoveFeatures | int(PMFEAT_ITEMPICK) | int(PMFEAT_GUNBLADEAUTOATTACK) );
            if ( gametype.isInstagib )
            {
                        this.carrier.client.inventoryGiveItem( WEAP_INSTAGUN );
                        this.carrier.client.inventorySetCount( AMMO_INSTAS, 1 );
                        this.carrier.client.inventorySetCount( AMMO_WEAK_INSTAS, 1 );
            }
            else
            {
                  this.carrier.client.inventoryGiveItem(WEAP_GUNBLADE);
				  this.carrier.client.inventorySetCount(AMMO_GUNBLADE, 10);
                  if( ! dmAllowPickup.boolean )
                  {
                        Item @item;
                        Item @ammoItem;
                  
                        // give all weapons
                        for ( int i = WEAP_GUNBLADE + 1; i < WEAP_TOTAL; i++ )
                        {
                            if ( i == WEAP_INSTAGUN ) // dont add instagun...
                                continue;

                            this.carrier.client.inventoryGiveItem( i );

                            @item = @G_GetItem( i );

                            @ammoItem = @G_GetItem( item.weakAmmoTag );
                            if ( @ammoItem != null )
                                this.carrier.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

                            @ammoItem = @G_GetItem( item.ammoTag );
                            if ( @ammoItem != null )
                                this.carrier.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );
                        }
                  }
            }
        this.carrier.client.selectWeapon( -1 );
        G_AnnouncerSound( null, prcAnnouncerChickenDrop, GS_MAX_TEAMS, true, null );
        G_PrintMsg( null, carrier.client.name + " has dropped the Chicken ! \n" );

        if ( ( G_PointContents( this.carrier.origin ) & CONTENTS_NODROP ) == 0 )
        {

            this.drop_chick( this.carrier );
            Entity @chicken = this.chicken;
            Trace tr;
            Vec3 end, dir, temp1, temp2;
            Vec3 mins( -16.0, -16.0, -16.0 ), maxs( 16.0, 16.0, 40.0 );
            carrier.angles.angleVectors( dir, temp1, temp2 );
            end = ( carrier.origin + ( 0.5 * ( maxs + mins ) ) ) + ( dir * 24 );

            tr.doTrace( carrier.origin, mins, maxs, end, carrier.entNum, MASK_SOLID );

            chicken.origin = tr.endPos;
            chicken.origin2 = tr.endPos;

            //G_PrintMsg( null, carrier.client.name + " has " + carrier.velocity + "\n");
            Vec3 player_velocity;
            player_velocity = this.carrier.velocity;
            bool no_x = false;
            bool no_y = false;

            if (!((dir.x > 0 && player_velocity.x > 0) || (dir.x < 0 && player_velocity.x < 0))) {
                no_x = true;
            }
            if (!((dir.y > 0 && player_velocity.y > 0) || (dir.y < 0 && player_velocity.y < 0))) {
                no_y = true;
            }

            if (no_y && no_x){
                dir *= 100 * chickenDropDistance;
            }else if (!no_y && !no_x) {
                dir *= 50 * chickenDropDistance;
            }else{
                dir *= 75 * chickenDropDistance;
            }

            if (dir.x > 0 && player_velocity.x > 0){
                dir.x += player_velocity.x;
            }else if (dir.x < 0 && player_velocity.x < 0) {
                dir.x += player_velocity.x;
            }
           
            if (dir.y > 0 && player_velocity.y > 0){
                dir.y += player_velocity.y;
            }else if (dir.y < 0 && player_velocity.y < 0) {
                dir.y += player_velocity.y;
            }

            if (dir.z >= 0){
                if (dir.z < 300){
                    dir.z = 300;
                    if (player_velocity.z > 0){
	                    dir.z += (player_velocity.z * 2 / 3);
	                }
                }
                if(player_velocity.z == 0){
                    dir.z *= 1.5;
                }
            }else if (dir.z < 0){
                if (dir.z > -5){
                    dir.z = 260;
                }else if (dir.z > -10){
                    dir.z = 230;
                }else if (dir.z > -20){
                    dir.z = 200;
                }else if (dir.z > -25){
                    dir.z = 170;
                }else if (dir.z > -31){
                    dir.z = 150;
                }
                else if (player_velocity.z < 0) {
                    dir.z += (player_velocity.z * 2 / 3);
                }
            }

            //G_PrintMsg( null,"passChicken2("+dir.x+","+dir.y+","+dir.z+")\n" );
            chicken.velocity = dir;

            chicken.linkEntity();
        }
        else
            this.spawn();


        this.dropper = carrier.playerNum;
        this.droppedTime = levelTime + 1000;
        chicken.nextThink = levelTime + 15000;
        @this.carrier = null;
        @this.chicken = @chicken;

    }

    void think(){
        if ( @this.carrier == null || @this.carrier.client == null )
            return;
        this.carrier.effects |= EF_GODMODE;
        if ( this.carrier.health < 125 )
            this.carrier.health += frameTime * 0.001f;
			
        if ( this.carrier.client.armor < 75 )
            this.carrier.client.armor += frameTime * 0.0005f;

        if ( this.nextScore <= levelTime )
        {
            if ( this.currentScoreOfRunner < MAX_SCORE_PER_RUN )
            {
                 this.carrier.client.stats.addScore( 1 );
                 G_GetTeam(this.carrier.team).stats.addScore( 1 );
                 this.currentScoreOfRunner++;
				 this.nextScore = levelTime + RUN_SCOREINTERVAL;
            }
            else
            {
                 if ( showMessageOfScorelimitPerRun )
                 {
                      this.carrier.client.printMessage( S_COLOR_RED + "SCORELIMIT AT NORMAL SPEED : " + MAX_SCORE_PER_RUN + " POINTS REACHED\n" );
                      this.carrier.client.printMessage( S_COLOR_WHITE + "you have to give the chicken to your partners in order to continue scoring fast\n" );
                      this.carrier.client.addAward( S_COLOR_RED + "SHARE THE CHICKEN WITH A TEAM MATE TO SCORE FASTER!" );
                      showMessageOfScorelimitPerRun = false;
					  
                 }
				 this.carrier.client.stats.addScore( 1 );
                 G_GetTeam(this.carrier.team).stats.addScore( 1 );
				 this.currentScoreOfRunner++;
				 this.nextScore = levelTime + RUN_SCOREINTERVAL_DEBUFF;
            }
            
        }
    }

    void damage( Entity @target, Entity @attacker, Entity @inflicter ){
        if ( @target == null )
            return;

        if ( @attacker == null )
            return;

        if ( @target == @this.carrier )
            return;
    }
}

void GT_PlayerRespawn(Entity @ent, int old_team, int new_team) {
 if ( old_team != new_team )
    {
    }

    if ( ent.isGhosting() )
        return;

    if ( gametype.isInstagib )
    {
        ent.client.inventoryGiveItem( WEAP_INSTAGUN );
        ent.client.inventorySetCount( AMMO_INSTAS, 1 );
        ent.client.inventorySetCount( AMMO_WEAK_INSTAS, 1 );
    }
    else
    {
        Item @item;
        Item @ammoItem;

        // the gunblade can't be given (because it can't be dropped)
        ent.client.inventorySetCount( WEAP_GUNBLADE, 1 );

        @item = @G_GetItem( WEAP_GUNBLADE );

        @ammoItem = @G_GetItem( item.ammoTag );
        if ( @ammoItem != null )
            ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

        @ammoItem = item.weakAmmoTag == AMMO_NONE ? null : @G_GetItem( item.weakAmmoTag );
        if ( @ammoItem != null )
            ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

        if ( match.getState() <= MATCH_STATE_WARMUP )
        {
            for ( int i = WEAP_GUNBLADE + 1; i < WEAP_TOTAL; i++ )
            {
                if ( i == WEAP_INSTAGUN ) // dont add instagun...
                    continue;

                ent.client.inventoryGiveItem( i );

                @item = @G_GetItem( i );

                @ammoItem = @G_GetItem( item.ammoTag );
                if ( @ammoItem != null )
                    ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );

                @ammoItem = item.weakAmmoTag == AMMO_NONE ? null : @G_GetItem( item.weakAmmoTag );
                if ( @ammoItem != null )
                    ent.client.inventorySetCount( ammoItem.tag, ammoItem.inventoryMax );
            }

            // give him 2 YAs
            ent.client.inventoryGiveItem( ARMOR_YA );
            ent.client.inventoryGiveItem( ARMOR_YA );
        }
    }
	
    if ( @ent == @chicken.carrier )
        chicken.spawn();
	
    // select rocket launcher if available
    if ( ent.client.canSelectWeapon( WEAP_ROCKETLAUNCHER ) )
        ent.client.selectWeapon( WEAP_ROCKETLAUNCHER );
    else
        ent.client.selectWeapon( -1 ); // auto-select best weapon in the inventory

    // add a teleportation effect
    ent.respawnEffect();
}

Entity @GT_SelectSpawnPoint(Entity @self) {
    return GENERIC_SelectBestRandomSpawnPoint( self, "info_player_deathmatch" );
}

void GT_MatchStateStarted(){
    switch ( match.getState() )
    {
	case MATCH_STATE_WARMUP:
        gametype.pickableItemsMask = gametype.spawnableItemsMask;
        gametype.dropableItemsMask = gametype.spawnableItemsMask;
        GENERIC_SetUpWarmup();
        break;

    case MATCH_STATE_COUNTDOWN:
        gametype.pickableItemsMask = 0; // disallow item pickup
        gametype.dropableItemsMask = 0; // disallow item drop
        GENERIC_SetUpCountdown();
        break;
		
    case MATCH_STATE_PLAYTIME:
        gametype.pickableItemsMask = gametype.spawnableItemsMask;
        gametype.dropableItemsMask = gametype.spawnableItemsMask;
        GENERIC_SetUpMatch();
        chicken.spawn();
        break;

    case MATCH_STATE_POSTMATCH:
        gametype.pickableItemsMask = 0; // disallow item pickup
        gametype.dropableItemsMask = 0; // disallow item drop
        GENERIC_SetUpEndMatch();
        break;

    default:
        break;
    }
}

bool GT_UpdateBotStatus(Entity @ent) {
	return GENERIC_UpdateBotStatus(ent);
}

bool GT_MatchStateFinished( int incomingMatchState ){
    if ( match.getState() <= MATCH_STATE_WARMUP
         && incomingMatchState > MATCH_STATE_WARMUP
         && incomingMatchState < MATCH_STATE_POSTMATCH )
    {
        match.startAutorecord();
    }

    if ( match.getState() == MATCH_STATE_POSTMATCH )
        match.stopAutorecord();

    return true;
}

String @GT_ScoreboardMessage(uint maxlen) {
	String scoreboardMessage = "";
    String entry;
    Team @team;
    Entity @ent;
    int i, t, carrierIcon, readyIcon;
	
    for ( t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++ )
    {   @team = @G_GetTeam( t );

        // &t = team tab, team tag, team score (doesn't apply), team ping (doesn't apply)
        entry = "&t " + t + " " + team.stats.score + " " + team.ping + " ";
	
		if ( scoreboardMessage.len() + entry.len() < maxlen )
			scoreboardMessage += entry;

        for ( i = 0; @team.ent( i ) != null; i++ )
        {   @ent = @team.ent( i );

            if ( ent.client.isReady() )
                readyIcon = prcYesIcon;
            else
                readyIcon = 0;
				
			if( @ent == @chicken.carrier )  
			{	carrierIcon = prcChickenIcon;	}
			else if(ent.client.inventoryCount(POWERUP_QUAD) > 0) 
			{	carrierIcon = prcShockIcon;		} 
			else if(ent.client.inventoryCount(POWERUP_SHELL) > 0) 
			{	carrierIcon = prcShellIcon; 	}
			   else
			{   carrierIcon = 0;  				}
                
            int playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;
			
            // "Name Clan Score Frags TKs Ping R"
            // Team Kill added in scoreboard
            entry = "&p " + playerID + " "
                    + ent.client.clanName + " "
                    + ent.client.stats.score + " "
                    + ent.client.stats.frags + " "
                    + ent.client.stats.teamFrags + " "
                    + ent.client.ping + " "
					+ carrierIcon + " "
                    + readyIcon + " ";	

            if ( scoreboardMessage.len() + entry.len() < maxlen )
                scoreboardMessage += entry;
        }
		}
    return scoreboardMessage;
}

void GT_ScoreEvent(Client @client, const String &score_event, const String &args){
    Entity @attacker = null;
    if ( @client != null )
    @attacker = @client.getEnt();

    int arg1 = args.getToken( 0 ).toInt();
    int arg2 = args.getToken( 1 ).toInt();
	int arg3 = args.getToken( 2 ).toInt();
    int arg4 = args.getToken( 3 ).toInt();

    if ( score_event == "dmg" )
    {
        chicken.damage( G_GetEntity( arg3 ), attacker, G_GetEntity( arg4 ) );
    }
    else if ( score_event == "kill" )
    {
        CTC_playerKilled( G_GetEntity( arg1 ), attacker, G_GetEntity( arg2 ) );
    }
    else if ( score_event == "award" )
    {
    }
}

void GT_InitGametype(){
	//Create default cfg file and execute it if not already exists
   String szCfgFile = "configs/server/gametypes/" + gametype.name + ".cfg"; //Setup cfg file name
    if (!G_FileExists(szCfgFile)) { //Check if there isn't a gametype related cfg file yet
    
        //Setup string with default content
        String szContent = "//'" + gametype.title + "' gametype configuration file\n"
                + "// This config will be executed each time the gametype is started\n"
                + "\n\n// map rotation\n"
                + "set g_maplist \"wdm1 wdm2 wdm4 wdm6 wdm7 wdm10 wdm12 wdm13 wdm14 wca1 wca3 wctf1 wctf3 wctf5 wctf6 \" // list of maps in automatic rotation\n"
                + "set g_maprotation \"2\"   // 0 = same map, 1 = in order, 2 = random\n"
                + "\n// game settings\n"
                + "set g_scorelimit \"100\"\n"
                + "set g_timelimit \"0\"\n"
                + "set g_warmup_timelimit \"2\"\n"
                + "set g_match_extendedtime \"0\"\n"
                + "set g_allow_falldamage \"0\"\n" 
                + "set g_allow_selfdamage \"0\"\n"
                + "set g_allow_teamdamage \"1\"\n"
                + "set g_allow_stun \"1\"\n"
                + "set g_teams_maxplayers \"0\"\n"
                + "set g_teams_allow_uneven \"0\"\n"
                + "set g_countdown_time \"5\"\n"
                + "set g_maxtimeouts \"3\" // -1 = unlimited\n"
                + "set g_challengers_queue \"0\"\n"
                + "set dm_allowPowerups \"1\"\n"
                + "set dm_powerupDrop \"1\"\n"
                + "\necho \"" + gametype.name + ".cfg executed\"\n";
				
        G_WriteFile(szCfgFile, szContent); //Write content to file
        G_Print("Created default config file for '" + gametype.name + "'\n"); //Output info message
        G_CmdExecute("exec " + szCfgFile + " silent"); //Execute the cfg file
    }
	    if ( dmAllowPickup.boolean ){
		gametype.spawnableItemsMask = IT_WEAPON | IT_AMMO | IT_ARMOR | IT_POWERUP | IT_HEALTH;
	}
		if (! dmAllowPickup.boolean ){
		gametype.spawnableItemsMask &= ~IT_POWERUP;
	}
		if(gametype.isInstagib) {
		gametype.spawnableItemsMask &= ~uint(G_INSTAGIB_NEGATE_ITEMMASK);
	}
	gametype.respawnableItemsMask = gametype.spawnableItemsMask;
	gametype.dropableItemsMask = gametype.spawnableItemsMask;
	gametype.pickableItemsMask = gametype.spawnableItemsMask | gametype.dropableItemsMask;

	gametype.isTeamBased = true;
	gametype.isRace = false;
	gametype.hasChallengersQueue = false;
	gametype.maxPlayersPerTeam = 0;

	gametype.ammoRespawn = 20;
	gametype.armorRespawn = 25;
	gametype.weaponRespawn = 15;
	gametype.healthRespawn = 25;
	gametype.powerupRespawn = 90;
	gametype.megahealthRespawn = 20;
	gametype.ultrahealthRespawn = 60;
	gametype.readyAnnouncementEnabled = true;

	gametype.scoreAnnouncementEnabled = true;
	gametype.countdownEnabled = true;
	gametype.mathAbortDisabled = false;
	gametype.shootingDisabled = false;
	gametype.infiniteAmmo = false;
	gametype.canForceModels = true;
	gametype.canShowMinimap = true;
	gametype.teamOnlyMinimap = true;

	gametype.spawnpointRadius = 256;
	if(gametype.isInstagib) {
		gametype.spawnpointRadius *= 2;
	}

	// set spawnsystem type to instant while players join
	for(int t = TEAM_PLAYERS; t < GS_MAX_TEAMS; t++) {
		gametype.setTeamSpawnsystem(t, SPAWNSYSTEM_INSTANT, 0, 0, false);
	}

	// define the scoreboard layout
	if(gametype.isInstagib) {
		G_ConfigString(CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %i 52 %l 48 %p 18");
		G_ConfigString(CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Dfrst Ping R");
	} else {
		G_ConfigString(CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %i 52 %i 52 %l 48 " + "%p 18 " + "%p 18");
		G_ConfigString(CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Frags Dfrst Ping " + "C " + " R");
	}

    gametype.title = C_GAMETYPE_NAME;
    gametype.version = C_GAMETYPE_VERSION;
    gametype.author = C_GAMETYPE_AUTHOR;

	// precache images that can be used by the scoreboard
	prcYesIcon = G_ImageIndex("gfx/hud/icons/vsay/yes");
	prcShockIcon = G_ImageIndex("gfx/hud/icons/powerup/quad");
	prcShellIcon = G_ImageIndex("gfx/hud/icons/powerup/warshell");
    prcChickenIcon = G_ImageIndex( "gfx/ctc/ChickenIcon.tga");
    prcCarrierIcon = G_ImageIndex( "gfx/ctc/chickenHUD.tga");

    //Precache chicken's "In Hand" model
    modelChickenhand = G_ModelIndex( "models/ctc/pouletmain.md3", true);

    // precache Chicken's sounds
    prcAnnouncerChickenTaken = G_SoundIndex( "sounds/ctc/taken", true);
    prcAnnouncerChickenDrop = G_SoundIndex( "sounds/ctc/drop", true);
    
    // precache Crap sounds
    prcAnnouncerPhilippe = G_SoundIndex( "sounds/ctc/philippe", true);
    prcAnnouncerPrecoce = G_SoundIndex( "sounds/ctc/precoce", true);
    prcAnnouncerPatron = G_SoundIndex( "sounds/ctc/patron", true);

    // add commands
    G_RegisterCommand( "drop" );
    G_RegisterCommand( "help" );
    G_RegisterCommand( "philippe" );
    G_RegisterCommand( "precoce" );
    G_RegisterCommand( "patron" );
    G_RegisterCommand( "classaction1" );
    G_RegisterCommand( "classaction2" );

    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
}

void GT_Shutdown() {
	// the gametype is shutting down cause of a match restart or map change
}

bool GT_Command(Client @client, const String &cmdString, const String &argsString, int argc) {
	if(cmdString == "drop") {
		String token;
		for(int i = 0; i < argc; i++) {
			token = argsString.getToken(i);
			if(token.len() == 0) {
				break;
			}

			if(token == "fullweapon") {
				GENERIC_DropCurrentWeapon(client, true);
				GENERIC_DropCurrentAmmoStrong(client);
			} else if(token == "weapon") {
				GENERIC_DropCurrentWeapon(client, true);
			} else if(token == "strong") {
				GENERIC_DropCurrentAmmoStrong(client);
			} else {
				GENERIC_CommandDropItem(client, token);
			}
		}
		return true;
	} 
	else if(cmdString == "help") 
	{
		String response = "";
		Cvar fs_game("fs_game", "", 0);
		String manifest = gametype.manifest;
		response += "\n";
		response += "Gametype " + gametype.name + " : " + gametype.title + "\n";
		response += "----------------\n";
		response += "Version: " + gametype.version + "\n";
		response += "Author: " + gametype.author + "\n";
		response += "Mod: " + fs_game.string + (manifest.length() > 0 ? " (manifest: " + manifest + ")" : "") + "\n";
        response += "\n";
        response += "^3A chicken randomly spawn in the map, to earn points, a member of your team must catch the chicken and keep it as long as possible.\n";
        response += "^3(your team will earn 1 point every " + ( RUN_SCOREINTERVAL / 1000 ) + " seconds)\n";
        response += "^3But ^1BEWARE^3 ! The chicken's carrier have no weapons, so if a member of your team has the chicken, DEFEND HIM !\n";
        response += "^3(You will get points for that :D)\n";
        response += "^3Conversely, if a member of the opposing team has the chicken, KILL HIM !\n";
        response += "^3(You will also get points for that :D)\n";
        response += "^1TIP #1 ^3: You can launch the chicken witch ClassAction1(short distance) or ClassAction2 (long distance) !\n";
        response += "^1TIP #2 ^3: There is a scorelimit per run of " + MAX_SCORE_PER_RUN + " points !";
		response += "When you have reached this scorelimit you score 2 times slower,\n";
        response += "^3           you should consider giving your chicken to your partners to score faster !\n";
		response += "----------------\n";
		G_PrintMsg(client.getEnt(), response);
		return true;
	}
	    else if ( cmdString == "classaction1" )
    {
        if ( @client.getEnt() == @chicken.carrier )
            chicken.passChicken();
    }

    else if ( cmdString == "classaction2" )
    {
        if ( @client.getEnt() == @chicken.carrier )
            chicken.passChicken2();
    }
	
    else if ( cmdString == "philippe" )
    {
        if( antiSimultaneousAnnounces < levelTime )
        {
             if( announcesNumber < MAX_NB_ANNOUNCER_ALLOWED )
             {
                  G_GlobalSound( CHAN_AUTO, prcAnnouncerPhilippe );
                  antiSimultaneousAnnounces = levelTime + 5505;
                  lastAnnounceTime = levelTime + 5505;
                  announcesNumber++;
             }
             else 
             {
                  G_PrintMsg( @client.getEnt(), "STOP SPAM YOU FOOOOOL ! " + ( ( lastAnnounceTime - levelTime + NB_ANNOUNCER_TIMEOUT ) / 1000 ) + " seconds remaining...\n" );
             }
        }
        else 
        {
             //G_PrintMsg( @client.getEnt(), "plz wait for crap sound to finish\n" );
        }
    }

    else if ( cmdString == "precoce" )
    {
       if( antiSimultaneousAnnounces < levelTime )
        {
             if( announcesNumber < MAX_NB_ANNOUNCER_ALLOWED )
             {
                  G_GlobalSound( CHAN_AUTO, prcAnnouncerPrecoce );
                  antiSimultaneousAnnounces = levelTime + 1969;
                  lastAnnounceTime = levelTime + 1969;
                  announcesNumber++;
             }
             else 
             {
                 G_PrintMsg( @client.getEnt(), "STOP SPAM YOU FOOOOOL ! " + ( ( lastAnnounceTime - levelTime + NB_ANNOUNCER_TIMEOUT ) / 1000 ) + " seconds remaining...\n" );
             }
        }
        else 
        {
             //G_PrintMsg( @client.getEnt(), "plz wait for crap sound to finish\n" );
        }
    }

    else if ( cmdString == "patron" )
    {
       if( antiSimultaneousAnnounces < levelTime )
        {
             if( announcesNumber < MAX_NB_ANNOUNCER_ALLOWED )
             {
                  G_GlobalSound( CHAN_AUTO, prcAnnouncerPatron );
                  antiSimultaneousAnnounces = levelTime + 2636;
                  lastAnnounceTime = levelTime + 2636;
                  announcesNumber++;
             }
             else 
             {
                  G_PrintMsg( @client.getEnt(), "STOP SPAM YOU FOOOOOL ! " + ( ( lastAnnounceTime - levelTime + NB_ANNOUNCER_TIMEOUT ) / 1000 ) + " seconds remaining...\n" );
             }
        }
        else 
        {
             //G_PrintMsg( @client.getEnt(), "plz wait for crap sound to finish\n" );
        }
    }
  
    else if ( cmdString == "callvotevalidate" )
    {
        String votename = argsString.getToken( 0 );
        if ( votename == "dm_allow_powerups" )
        {
            String voteArg = argsString.getToken( 1 );
            if ( voteArg.len() < 1 )
            {
                client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
                return false;
            }

            int value = voteArg.toInt();
            if ( voteArg != "0" && voteArg != "1" )
            {
                client.printMessage( "Callvote " + votename + " expects a 1 or a 0 as argument\n" );
                return false;
            }

            if ( voteArg == "0" && !dmAllowPowerups.boolean )
            {
                client.printMessage( "Powerups are already disallowed\n" );
                return false;
            }

            if ( voteArg == "1" && dmAllowPowerups.boolean )
            {
                client.printMessage( "Powerups are already allowed\n" );
                return false;
            }

            return true;
        }

        if ( votename == "dm_powerup_drop" )
        {
            String voteArg = argsString.getToken( 1 );
            if ( voteArg.len() < 1 )
            {
                client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
                return false;
            }

            int value = voteArg.toInt();
            if ( voteArg != "0" && voteArg != "1" )
            {
                client.printMessage( "Callvote " + votename + " expects a 1 or a 0 as argument\n" );
                return false;
            }

            if ( voteArg == "0" && !dmAllowPowerupDrop.boolean )
            {
                client.printMessage( "Powerup drop is already disallowed\n" );
                return false;
            }

            if ( voteArg == "1" && dmAllowPowerupDrop.boolean )
            {
                client.printMessage( "Powerup drop is already allowed\n" );
                return false;
            }

            return true;
        }
        
        if ( votename == "dm_allow_pickup" )
        {
            String voteArg = argsString.getToken( 1 );
            if ( voteArg.len() < 1 )
            {
                client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
                return false;
            }

            int value = voteArg.toInt();
            if ( voteArg != "0" && voteArg != "1" )
            {
                client.printMessage( "Callvote " + votename + " expects a 1 or a 0 as argument\n" );
                return false;
            }

            if ( voteArg == "0" && !dmAllowPickup.boolean )
            {
                client.printMessage( "Weapon pickup is already disallowed\n" );
                return false;
            }

            if ( voteArg == "1" && dmAllowPickup.boolean )
            {
                client.printMessage( "Weapon pickup is already allowed\n" );
                return false;
            }

            return true;
        }

        client.printMessage( "Unknown callvote " + votename + "\n" );
        return false;
    }
    else if ( cmdString == "callvotepassed" )
    {
        String votename = argsString.getToken( 0 );
        if ( votename == "dm_allow_powerups" )
        {
            if( argsString.getToken( 1 ).toInt() > 0 )
                dmAllowPowerups.set( 1 );
            else
                dmAllowPowerups.set( 0 );

            //Force a match restart to update
            match.launchState( MATCH_STATE_POSTMATCH );
            return true;
        }
        
        if ( votename == "dm_allow_pickup" )
        {
            if( argsString.getToken( 1 ).toInt() > 0 )
                dmAllowPickup.set( 1 );
            else
                dmAllowPickup.set( 0 );

            //Force a match restart to update
            match.launchState( MATCH_STATE_POSTMATCH );
            return true;
        }

        if ( votename == "dm_powerup_drop" )
        {
            if( argsString.getToken( 1 ).toInt() > 0 )
                dmAllowPowerupDrop.set( 1 );
            else
                dmAllowPowerupDrop.set( 0 );
        }

        return true;
    }
    else if( cmdString == "cvarinfo" )
    {
        return true;
    }
    return false;
}
	
void GT_SpawnGametype(){
    chicken.spawn();
}

void GT_ThinkRules(){
    if(match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished()) {
		match.launchState(match.getState() + 1);
	}

	GENERIC_Think();

    //We are in postmatch state so there is nothing to continue
    if (match.getState() >= MATCH_STATE_POSTMATCH)
        return;
        
    if ( lastAnnounceTime + NB_ANNOUNCER_TIMEOUT < levelTime && announcesNumber != 0 )
        announcesNumber = 0;

    chicken.think();
	
	GENERIC_Think();
	
	 for ( int i = 0; i < maxClients; i++ )
    {
        Entity @ent = @G_GetClient( i ).getEnt();

        if ( ent.client.state() >= CS_SPAWNED && ent.team != TEAM_SPECTATOR )
        {
            if ( ent.health > ent.maxHealth )
                ent.health -= ( frameTime * 0.001f );

            //GENERIC_ChargeGunblade( ent.client );
        }

		ent.client.setHUDStat( STAT_IMAGE_SELF, 0 );
        ent.client.setHUDStat( STAT_IMAGE_OTHER, 0 );
        ent.client.setHUDStat( STAT_IMAGE_ALPHA, 0 );
        ent.client.setHUDStat( STAT_IMAGE_BETA, 0 );
        ent.client.setHUDStat( STAT_MESSAGE_SELF, 0 );
        ent.client.setHUDStat( STAT_MESSAGE_OTHER, 0 );
        ent.client.setHUDStat( STAT_MESSAGE_ALPHA, 0 );
        ent.client.setHUDStat( STAT_MESSAGE_BETA, 0 );
		
        if ( ent.team == TEAM_ALPHA )
        {
            if ( @chicken.carrier != null )
            {
                if ( chicken.carrier.team == TEAM_ALPHA )
                    ent.client.setHUDStat( STAT_IMAGE_SELF, prcCarrierIcon );
                else if ( chicken.carrier.team == TEAM_BETA )
                    ent.client.setHUDStat( STAT_IMAGE_OTHER, prcCarrierIcon );
            }
        }
        else if ( ent.team == TEAM_BETA )
        {
            if ( @chicken.carrier != null )
            {
                if ( chicken.carrier.team == TEAM_ALPHA )
                    ent.client.setHUDStat( STAT_IMAGE_OTHER, prcCarrierIcon );
                else if ( chicken.carrier.team == TEAM_BETA )
                    ent.client.setHUDStat( STAT_IMAGE_SELF, prcCarrierIcon );
            }
        }
        else if ( ent.client.chaseActive == false )
        {
            if ( @chicken.carrier != null )
            {
                if ( chicken.carrier.team == TEAM_ALPHA )
                    ent.client.setHUDStat( STAT_IMAGE_ALPHA, prcCarrierIcon );
                else if ( chicken.carrier.team == TEAM_BETA )
                    ent.client.setHUDStat( STAT_IMAGE_BETA, prcCarrierIcon );
            }
        }
    }
}