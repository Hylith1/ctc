void team_CTF_genericSpawnpoint( Entity @ent, int team )
{
    ent.team = team;

    // drop to floor

    Trace tr;
    Vec3 start, end, mins( -16.0f, -16.0f, -24.0f ), maxs( 16.0f, 16.0f, 40.0f );

    end = start = ent.origin;
    end.z -= 1024;
    start.z += 16;

    // check for starting inside solid
    tr.doTrace( start, mins, maxs, start, ent.entNum, MASK_DEADSOLID );
    if ( tr.startSolid || tr.allSolid )
    {
        G_Print( ent.classname + " starts inside solid. Inhibited\n" );
        ent.freeEntity();
        return;
    }

    if ( ( ent.spawnFlags & 1 ) == 0 ) // do not drop if having the float flag
    {
        if ( tr.doTrace( start, mins, maxs, end, ent.entNum, MASK_DEADSOLID ) )
        {
            start = tr.endPos + tr.planeNormal;
            ent.origin = start;
            ent.origin2 = start;
        }
    }
}

void team_CTF_alphaspawn( Entity @ent )
{
    team_CTF_genericSpawnpoint( ent, TEAM_ALPHA );
}

void team_CTF_betaspawn( Entity @ent )
{
    team_CTF_genericSpawnpoint( ent, TEAM_BETA );
}

void team_CTF_alphaplayer( Entity @ent )
{
    team_CTF_genericSpawnpoint( ent, TEAM_ALPHA );
}

void team_CTF_betaplayer( Entity @ent )
{
    team_CTF_genericSpawnpoint( ent, TEAM_BETA );
}
