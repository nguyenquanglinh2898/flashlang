package com.example.flash_lang.wear

import org.json.JSONArray
import org.json.JSONObject

data class FlashLangSnapshot(
    val schemaVersion: Int,
    val syncedAt: Long,
    val settings: FlashLangSettings,
    val groups: List<FlashLangGroup>,
    val cards: List<FlashLangCard>,
)

data class FlashLangSettings(
    val pushTimes: List<String>,
    val scheduleMode: FlashLangScheduleMode,
    val intervalMinutes: Int?,
)

data class FlashLangGroup(
    val id: Int,
    val name: String,
    val createdAt: String,
    val cardCount: Int,
)

data class FlashLangCard(
    val id: Int,
    val word: String,
    val createdAt: Long,
    val partOfSpeech: String?,
    val phonetic: String?,
    val meaning: String,
    val imagePath: String?,
    val groups: List<String>,
    val lastPushedAt: Long?,
) {
    fun notificationTitle(): String {
        val abbreviation = partOfSpeechAbbreviation(partOfSpeech)
        return if (abbreviation.isNullOrBlank()) word else "$word ($abbreviation)"
    }
}

enum class FlashLangScheduleMode {
    FIXED_TIMES,
    INTERVAL,
}

fun parseSnapshotJson(raw: String): FlashLangSnapshot {
    val root = JSONObject(raw)
    return FlashLangSnapshot(
        schemaVersion = root.optInt("schemaVersion", 1),
        syncedAt = parseSyncedAt(root.optString("syncedAt")),
        settings = parseSettings(root.getJSONObject("settings")),
        groups = parseGroups(root.optJSONArray("groups")),
        cards = parseCards(root.optJSONArray("cards")),
    )
}

fun snapshotToJson(snapshot: FlashLangSnapshot): JSONObject {
    return JSONObject().apply {
        put("schemaVersion", snapshot.schemaVersion)
        put("syncedAt", formatIso(snapshot.syncedAt))
        put("settings", settingsToJson(snapshot.settings))
        put("groups", JSONArray(snapshot.groups.map { groupToJson(it) }))
        put("cards", JSONArray(snapshot.cards.map { cardToJson(it) }))
    }
}

private fun parseSettings(json: JSONObject): FlashLangSettings {
    val mode = when (json.optString("scheduleMode")) {
        FlashLangScheduleMode.INTERVAL.name.lowercase() -> FlashLangScheduleMode.INTERVAL
        "interval" -> FlashLangScheduleMode.INTERVAL
        else -> FlashLangScheduleMode.FIXED_TIMES
    }
    return FlashLangSettings(
        pushTimes = json.optJSONArray("pushTimes").toStringList(),
        scheduleMode = mode,
        intervalMinutes = if (json.isNull("intervalMinutes")) null else json.optInt("intervalMinutes"),
    )
}

private fun parseGroups(array: JSONArray?): List<FlashLangGroup> {
    if (array == null) return emptyList()
    return buildList {
        for (i in 0 until array.length()) {
            val json = array.getJSONObject(i)
            add(
                FlashLangGroup(
                    id = json.optInt("id"),
                    name = json.optString("name"),
                    createdAt = json.optString("createdAt"),
                    cardCount = json.optInt("cardCount"),
                ),
            )
        }
    }
}

private fun parseCards(array: JSONArray?): List<FlashLangCard> {
    if (array == null) return emptyList()
    return buildList {
        for (i in 0 until array.length()) {
            val json = array.getJSONObject(i)
            add(
                FlashLangCard(
                    id = json.optInt("id"),
                    word = json.optString("word"),
                    createdAt = parseIsoLong(json.optString("createdAt")),
                    partOfSpeech = json.optStringOrNull("partOfSpeech"),
                    phonetic = json.optStringOrNull("phonetic"),
                    meaning = json.optString("meaning"),
                    imagePath = json.optStringOrNull("imagePath"),
                    groups = json.optGroups(),
                    lastPushedAt = json.optLastPushedAt(),
                ),
            )
        }
    }
}

private fun settingsToJson(settings: FlashLangSettings): JSONObject {
    return JSONObject().apply {
        put("pushTimes", JSONArray(settings.pushTimes))
        put("scheduleMode", settings.scheduleMode.name.lowercase())
        put("intervalMinutes", settings.intervalMinutes)
    }
}

private fun groupToJson(group: FlashLangGroup): JSONObject {
    return JSONObject().apply {
        put("id", group.id)
        put("name", group.name)
        put("createdAt", group.createdAt)
        put("cardCount", group.cardCount)
    }
}

private fun cardToJson(card: FlashLangCard): JSONObject {
    return JSONObject().apply {
        put("id", card.id)
        put("word", card.word)
        put("createdAt", formatIso(card.createdAt))
        put("partOfSpeech", card.partOfSpeech)
        put("phonetic", card.phonetic)
        put("meaning", card.meaning)
        put("imagePath", card.imagePath)
        put("groups", JSONArray(card.groups))
        put("lastPushedAt", card.lastPushedAt)
    }
}

private fun JSONArray?.toStringList(): List<String> {
    if (this == null) return emptyList()
    return buildList {
        for (i in 0 until length()) {
            add(optString(i))
        }
    }.filter { it.isNotBlank() }
}

private fun JSONObject.optGroups(): List<String> {
    val rawArray = optJSONArray("groups")
    if (rawArray != null) {
        return rawArray.toStringList()
    }

    val rawString = optString("groups")
    return rawString.split(";")
        .map { it.trim() }
        .filter { it.isNotBlank() }
}

private fun JSONObject.optLastPushedAt(): Long? {
    if (isNull("lastPushedAt")) return null
    val rawValue = opt("lastPushedAt")
    return when (rawValue) {
        is Number -> rawValue.toLong()
        is String -> runCatching { java.time.Instant.parse(rawValue).toEpochMilli() }.getOrNull()
        else -> null
    }
}

private fun JSONObject.optStringOrNull(key: String): String? {
    val value = optString(key)
    return value.takeIf { it.isNotBlank() }
}

private fun parseSyncedAt(raw: String): Long {
    return try {
        if (raw.isBlank()) {
            System.currentTimeMillis()
        } else {
            java.time.Instant.parse(raw).toEpochMilli()
        }
    } catch (_: Throwable) {
        System.currentTimeMillis()
    }
}

private fun parseIsoLong(raw: String): Long {
    return try {
        if (raw.isBlank()) {
            System.currentTimeMillis()
        } else {
            java.time.Instant.parse(raw).toEpochMilli()
        }
    } catch (_: Throwable) {
        System.currentTimeMillis()
    }
}

private fun formatIso(epochMillis: Long): String {
    return java.time.Instant.ofEpochMilli(epochMillis).toString()
}

fun partOfSpeechAbbreviation(value: String?): String? {
    val normalized = value?.trim()?.lowercase().orEmpty()
    if (normalized.isBlank()) return null

    return when (normalized) {
        "noun" -> "n"
        "verb" -> "v"
        "adjective" -> "adj"
        "adverb" -> "adv"
        "pronoun" -> "pron"
        "preposition" -> "prep"
        "conjunction" -> "conj"
        "interjection" -> "int"
        "phrasal verb" -> "phr v"
        "noun phrase" -> "n phr"
        "verb phrase" -> "v phr"
        "idiom" -> "idm"
        else -> value?.trim().orEmpty()
    }
}
