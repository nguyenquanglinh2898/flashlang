package com.example.flash_lang.wear

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView

sealed interface WearBrowseItem {
    val stableId: Long

    data class GroupItem(val group: FlashLangGroup) : WearBrowseItem {
        override val stableId: Long = 1_000_000L + group.id
    }

    data class CardItem(val card: FlashLangCard) : WearBrowseItem {
        override val stableId: Long = 2_000_000L + card.id
    }

    data class InfoItem(
        val title: String,
        val body: String,
        val meta: String? = null,
    ) : WearBrowseItem {
        override val stableId: Long = (title + body + meta.orEmpty()).hashCode().toLong()
    }
}

class FlashLangBrowseAdapter(
    private val onItemClick: (WearBrowseItem) -> Unit,
) : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
    private var items: List<WearBrowseItem> = emptyList()

    init {
        setHasStableIds(true)
    }

    override fun getItemViewType(position: Int): Int {
        return when (items[position]) {
            is WearBrowseItem.GroupItem -> VIEW_TYPE_GROUP
            is WearBrowseItem.CardItem -> VIEW_TYPE_CARD
            is WearBrowseItem.InfoItem -> VIEW_TYPE_INFO
        }
    }

    override fun getItemId(position: Int): Long = items[position].stableId

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val inflater = LayoutInflater.from(parent.context)
        return when (viewType) {
            VIEW_TYPE_GROUP -> GroupViewHolder(
                inflater.inflate(R.layout.item_wear_group, parent, false),
            )

            VIEW_TYPE_INFO -> InfoViewHolder(
                inflater.inflate(R.layout.item_wear_info, parent, false),
            )

            else -> CardViewHolder(
                inflater.inflate(R.layout.item_wear_card, parent, false),
            )
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        when (val item = items[position]) {
            is WearBrowseItem.GroupItem -> (holder as GroupViewHolder).bind(item, onItemClick)
            is WearBrowseItem.CardItem -> (holder as CardViewHolder).bind(item, onItemClick)
            is WearBrowseItem.InfoItem -> (holder as InfoViewHolder).bind(item)
        }
    }

    override fun getItemCount(): Int = items.size

    fun submitList(newItems: List<WearBrowseItem>) {
        items = newItems
        notifyDataSetChanged()
    }

    class GroupViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        private val title: TextView = view.findViewById(R.id.groupTitle)
        private val subtitle: TextView = view.findViewById(R.id.groupSubtitle)
        private val meta: TextView = view.findViewById(R.id.groupMeta)

        fun bind(item: WearBrowseItem.GroupItem, onClick: (WearBrowseItem) -> Unit) {
            title.text = item.group.name
            subtitle.text = if (item.group.cardCount == 1) {
                "1 card"
            } else {
                "${item.group.cardCount} cards"
            }
            meta.text = "Tap to open"
            itemView.setOnClickListener { onClick(item) }
        }
    }

    class CardViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        private val title: TextView = view.findViewById(R.id.cardTitle)
        private val subtitle: TextView = view.findViewById(R.id.cardSubtitle)
        private val meta: TextView = view.findViewById(R.id.cardMeta)

        fun bind(item: WearBrowseItem.CardItem, onClick: (WearBrowseItem) -> Unit) {
            val card = item.card
            title.text = card.notificationTitle()
            subtitle.text = card.meaning
            meta.text = buildString {
                val abbreviation = partOfSpeechAbbreviation(card.partOfSpeech)
                if (!abbreviation.isNullOrBlank()) {
                    append(abbreviation)
                }
                if (card.groups.isNotEmpty()) {
                    if (isNotEmpty()) append(" · ")
                    append(card.groups.first())
                }
            }.ifBlank { "Tap to open" }
            itemView.setOnClickListener { onClick(item) }
        }
    }

    class InfoViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        private val title: TextView = view.findViewById(R.id.infoTitle)
        private val body: TextView = view.findViewById(R.id.infoBody)
        private val meta: TextView = view.findViewById(R.id.infoMeta)

        fun bind(item: WearBrowseItem.InfoItem) {
            title.text = item.title
            body.text = item.body
            if (item.meta.isNullOrBlank()) {
                meta.visibility = View.GONE
            } else {
                meta.visibility = View.VISIBLE
                meta.text = item.meta
            }
            itemView.setOnClickListener(null)
        }
    }

    companion object {
        private const val VIEW_TYPE_GROUP = 0
        private const val VIEW_TYPE_CARD = 1
        private const val VIEW_TYPE_INFO = 2
    }
}
