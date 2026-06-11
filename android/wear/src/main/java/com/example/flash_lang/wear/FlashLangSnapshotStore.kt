package com.example.flash_lang.wear

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object FlashLangSnapshotStore {
    private const val PREFS_NAME = "flashlang_wear_store"
    private const val KEY_SNAPSHOT_JSON = "snapshot_json"

    fun saveSnapshotJson(context: Context, raw: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SNAPSHOT_JSON, raw)
            .apply()
    }

    fun loadSnapshot(context: Context): FlashLangSnapshot? {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SNAPSHOT_JSON, null)
            ?: return null

        return runCatching { parseSnapshotJson(raw) }.getOrNull()
    }

    fun updateSnapshot(context: Context, transform: (FlashLangSnapshot) -> FlashLangSnapshot): FlashLangSnapshot? {
        val current = loadSnapshot(context) ?: return null
        val updated = transform(current)
        saveSnapshotJson(context, snapshotToJson(updated).toString())
        return updated
    }

    fun getCardById(context: Context, cardId: Int): FlashLangCard? {
        return loadSnapshot(context)?.cards?.firstOrNull { it.id == cardId }
    }

    fun chooseNextCard(context: Context): FlashLangCard? {
        val cards = loadSnapshot(context)?.cards.orEmpty()
        if (cards.isEmpty()) return null

        val cutoff = System.currentTimeMillis() - (2L * 24 * 60 * 60 * 1000)
        val eligible = cards.filter { card ->
            val lastPushedAt = card.lastPushedAt
            lastPushedAt == null || lastPushedAt < cutoff
        }
        return if (eligible.isNotEmpty()) {
            eligible.minWith(compareBy<FlashLangCard> { it.lastPushedAt ?: 0L }.thenBy { it.createdAt }.thenBy { it.id })
        } else {
            cards.minWith(compareBy<FlashLangCard> { it.lastPushedAt ?: 0L }.thenBy { it.createdAt }.thenBy { it.id })
        }
    }

    fun markCardPushed(context: Context, cardId: Int, pushedAt: Long = System.currentTimeMillis()) {
        updateSnapshot(context) { snapshot ->
            snapshot.copy(
                cards = snapshot.cards.map { card ->
                    if (card.id == cardId) {
                        card.copy(lastPushedAt = pushedAt)
                    } else {
                        card
                    }
                },
            )
        }
    }

}
