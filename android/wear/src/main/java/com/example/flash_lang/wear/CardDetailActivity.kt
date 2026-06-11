package com.example.flash_lang.wear

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.view.View
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import java.util.Locale

class CardDetailActivity : AppCompatActivity(), TextToSpeech.OnInitListener {
    private var textToSpeech: TextToSpeech? = null
    private var currentCard: FlashLangCard? = null
    private val snapshotUpdatedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            renderCard()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_detail)

        textToSpeech = TextToSpeech(this, this)
        renderCard()

        findViewById<View>(R.id.speakButton).setOnClickListener {
            speak()
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            textToSpeech?.language = Locale.UK
        }
    }

    override fun onDestroy() {
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        super.onDestroy()
    }

    override fun onStart() {
        super.onStart()
        ContextCompat.registerReceiver(
            this,
            snapshotUpdatedReceiver,
            IntentFilter(FlashLangSyncEvents.ACTION_SNAPSHOT_UPDATED),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    override fun onStop() {
        unregisterReceiver(snapshotUpdatedReceiver)
        super.onStop()
    }

    private fun renderCard() {
        val cardId = intent.getIntExtra(FlashLangNotificationScheduler.EXTRA_CARD_ID, -1)
        currentCard = FlashLangSnapshotStore.getCardById(this, cardId)

        val card = currentCard
        val emptyView = findViewById<TextView>(R.id.emptyView)
        val contentCard = findViewById<View>(R.id.contentCard)

        if (card == null) {
            emptyView.visibility = View.VISIBLE
            contentCard.visibility = View.GONE
            emptyView.text = "Card not found."
            return
        }

        emptyView.visibility = View.GONE
        contentCard.visibility = View.VISIBLE

        findViewById<TextView>(R.id.wordView).text = card.notificationTitle()
        val partOfSpeechView = findViewById<TextView>(R.id.partOfSpeechView)
        val abbreviation = partOfSpeechAbbreviation(card.partOfSpeech)
        if (abbreviation.isNullOrBlank()) {
            partOfSpeechView.visibility = View.GONE
        } else {
            partOfSpeechView.text = abbreviation
            partOfSpeechView.visibility = View.VISIBLE
        }
        findViewById<TextView>(R.id.phoneticView).text = card.phonetic ?: ""
        findViewById<TextView>(R.id.meaningView).text = card.meaning
        findViewById<TextView>(R.id.groupsView).text = if (card.groups.isEmpty()) {
            "No groups"
        } else {
            card.groups.joinToString(" · ")
        }
        val imageHintView = findViewById<TextView>(R.id.imageHintView)
        imageHintView.visibility = if (card.imagePath.isNullOrBlank()) View.GONE else View.VISIBLE
    }

    private fun speak() {
        val card = currentCard ?: return
        textToSpeech?.speak(card.word, TextToSpeech.QUEUE_FLUSH, null, "flashlang-speak")
    }
}
