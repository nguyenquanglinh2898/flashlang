package com.example.flash_lang.wear

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.view.View
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.wear.widget.WearableRecyclerView

class MainActivity : AppCompatActivity() {
    private lateinit var recyclerView: WearableRecyclerView
    private lateinit var emptyView: TextView
    private lateinit var titleView: TextView
    private lateinit var subtitleView: TextView
    private lateinit var backButton: View
    private lateinit var adapter: FlashLangBrowseAdapter

    private var selectedGroupId: Int? = null

    private val snapshotUpdatedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            render()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        FlashLangNotificationScheduler.ensureChannel(this)

        titleView = findViewById(R.id.titleView)
        subtitleView = findViewById(R.id.subtitleView)
        backButton = findViewById(R.id.backButton)
        recyclerView = findViewById(R.id.cardRecyclerView)
        emptyView = findViewById(R.id.emptyView)

        adapter = FlashLangBrowseAdapter(::onItemSelected)
        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.isEdgeItemsCenteringEnabled = true
        recyclerView.isCircularScrollingGestureEnabled = false
        recyclerView.adapter = adapter

        backButton.setOnClickListener {
            if (selectedGroupId != null) {
                selectedGroupId = null
                render()
            } else {
                finish()
            }
        }

        render()

        intent?.getIntExtra(FlashLangNotificationScheduler.EXTRA_CARD_ID, -1)
            ?.takeIf { it >= 0 }
            ?.let { openCard(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getIntExtra(FlashLangNotificationScheduler.EXTRA_CARD_ID, -1)
            .takeIf { it >= 0 }
            ?.let { openCard(it) }
    }

    override fun onResume() {
        super.onResume()
        render()
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

    private fun render() {
        val snapshot = FlashLangSnapshotStore.loadSnapshot(this)
        val groups = snapshot?.groups.orEmpty().sortedBy { it.name.lowercase() }
        val cards = snapshot?.cards.orEmpty()
        val selectedGroup = groups.firstOrNull { it.id == selectedGroupId }
        if (selectedGroup == null) {
            selectedGroupId = null
        }

        if (selectedGroup == null) {
            titleView.text = "Groups"
            subtitleView.text = if (snapshot == null) {
                "Waiting for phone sync"
            } else {
                "${groups.size} groups · ${cards.size} cards"
            }
            backButton.alpha = 0.72f

            val items = groups.map { WearBrowseItem.GroupItem(it) }
            showItems(
                items = items,
                emptyMessage = "Sync from phone to see groups.",
            )
            return
        }

        titleView.text = selectedGroup.name
        subtitleView.text = if (selectedGroup.cardCount == 1) {
            "1 card"
        } else {
            "${selectedGroup.cardCount} cards"
        }
        backButton.alpha = 1f

        val items = cards
            .filter { card -> card.groups.contains(selectedGroup.name) }
            .sortedWith(compareBy<FlashLangCard> { it.word.lowercase() }.thenBy { it.id })
            .map { WearBrowseItem.CardItem(it) }

        showItems(
            items = items,
            emptyMessage = "No cards in this group.",
        )
    }

    private fun showItems(items: List<WearBrowseItem>, emptyMessage: String) {
        adapter.submitList(items)
        emptyView.text = emptyMessage
        emptyView.visibility = if (items.isEmpty()) View.VISIBLE else View.GONE
        recyclerView.visibility = if (items.isEmpty()) View.GONE else View.VISIBLE
    }

    private fun onItemSelected(item: WearBrowseItem) {
        when (item) {
            is WearBrowseItem.CardItem -> openCard(item.card.id)
            is WearBrowseItem.GroupItem -> {
                selectedGroupId = item.group.id
                render()
            }

            is WearBrowseItem.InfoItem -> Unit
        }
    }

    private fun openCard(cardId: Int) {
        startActivity(
            Intent(this, CardDetailActivity::class.java).apply {
                putExtra(FlashLangNotificationScheduler.EXTRA_CARD_ID, cardId)
            },
        )
    }
}
