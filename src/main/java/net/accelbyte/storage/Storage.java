package net.accelbyte.storage;

import net.accelbyte.custom.guild.GuildProgress;

public interface Storage {

    GuildProgress getGuildProgress(String namespace, String key) throws Exception;

    GuildProgress saveGuildProgress(String namespace, String key, GuildProgress value) throws Exception;
}
