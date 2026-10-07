import QtQuick

import "../../core/theme"

/**
 * ContentReveal — the staggered "expensive" entrance for a panel's contents.
 *
 * A panel does not simply fade in: its rows cascade, each fading up from nothing
 * and rising into place a beat after the one above. Call `play(item)` when a
 * panel opens (or when the selected panel changes while open) and every
 * top-level row of `item` is animated; call `stop()` when it closes.
 *
 * The rows are the direct children of the panel's content column. Panels that
 * wrap their column in a rounded container (a Rectangle / Flickable root) are
 * unwrapped automatically, so the cascade lands on the visible rows rather than
 * on the single wrapper. Repeater delegates are skipped: they often bind their
 * own `opacity` (the carousels do), and clobbering those would break them — the
 * wrapper they live in still reveals as a block.
 *
 * Movement is done with a `Translate` transform appended to each row, and the
 * fade writes the row's `opacity`; neither touches the layout, so the island
 * height never reflows while the rows travel. Safe to call repeatedly — the
 * per-row Translate and animations are created once and reused.
 *
 * All timings come from the Theme tokens (`contentStagger`,
 * `contentRevealDelay`, `contentRise`, `contentRevealDuration`); under Game Mode
 * / Reduce Motion they collapse to zero and `play()` does nothing at all.
 */
QtObject {
    id: reveal

    /// One record per row: the target Item, its shared Translate and the two
    /// animations driving it. Rebuilt lazily and pruned when a target dies.
    property var _recs: []
    /// The panel item the current records belong to. A new item means the old
    /// rows are on their way out, so their records are dropped wholesale instead
    /// of being left to dangle (see `play`).
    property var _root: null

    // A single Translate per row, tagged so we can find it again instead of
    // appending a new one on every open.
    property Component translateComp: Component {
        Translate { objectName: "__karuReveal" }
    }

    // Delay (a beat) then rise the row from `contentRise` to 0.
    property Component riseComp: Component {
        SequentialAnimation {
            id: rise
            property int stagger: 0
            property var targetItem: null
            PauseAnimation { duration: rise.stagger }
            NumberAnimation {
                target: rise.targetItem
                property: "y"
                from: Theme.contentRise
                to: 0
                duration: Theme.contentRevealDuration
                easing.type: Theme.easeOut
            }
        }
    }

    // Delay (a beat) then fade the row from nothing to fully visible.
    property Component fadeComp: Component {
        SequentialAnimation {
            id: fade
            property int stagger: 0
            property var targetItem: null
            PauseAnimation { duration: fade.stagger }
            NumberAnimation {
                target: fade.targetItem
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.contentRevealDuration
                easing.type: Theme.easeOut
            }
        }
    }

    /// Reveal `item`'s rows, staggered from the top down.
    function play(item) {
        if (!item || Theme.motionOff)
            return
        // A different root item means the previous panel has been (or is being)
        // rebuilt; its row objects are going away, so forget their records
        // rather than keep references that may already be deleted.
        if (item !== _root) {
            _root = item
            _recs = []
        }
        prune()
        var targets = collect(item)
        for (var i = 0; i < targets.length; ++i) {
            var t = targets[i]
            var rec = recordFor(t)
            var delay = Theme.contentRevealDelay + i * Theme.contentStagger
            try {
                t.opacity = 0
                if (rec.translate)
                    rec.translate.y = Theme.contentRise
            } catch (e) { continue }
            restartAnim(rec.rise, delay)
            restartAnim(rec.fade, delay)
        }
    }

    /// Halt every in-flight reveal and drop the rows back to their resting look.
    /// Every access is guarded: a row (or one of its child animations) can be
    /// destroyed at any moment when a panel unloads, and touching a deleted
    /// object throws rather than returning null.
    function stop() {
        for (var i = 0; i < _recs.length; ++i) {
            var r = _recs[i]
            if (!r.target)
                continue
            stopAnim(r.rise)
            stopAnim(r.fade)
            try {
                if (r.translate) r.translate.y = 0
                r.target.opacity = 1
            } catch (e) {}
        }
    }

    // ── Animation guards ─────────────────────────────────────────────────────
    // `restart()`/`stop()` on a record's animation must never throw: when the
    // panel that owned a row is torn down its child animations are destroyed
    // first, leaving a stale, truthy reference whose methods are gone.

    function restartAnim(anim, delay) {
        if (!anim)
            return
        try {
            anim.stagger = delay
            anim.restart()
        } catch (e) {}
    }

    function stopAnim(anim) {
        if (!anim)
            return
        try {
            anim.stop()
        } catch (e) {}
    }

    // ── Internals ────────────────────────────────────────────────────────────

    /// Find (or create) the record for a row, creating its Translate and
    /// animations on first sight.
    function recordFor(target) {
        for (var i = 0; i < _recs.length; ++i)
            if (_recs[i].target === target)
                return _recs[i]
        var tr = ensureTranslate(target)
        var rec = {
            target: target,
            translate: tr,
            rise: null,
            fade: null
        }
        if (tr) {
            rec.rise = riseComp.createObject(tr)
            if (rec.rise)
                rec.rise.targetItem = tr
        }
        rec.fade = fadeComp.createObject(target)
        if (rec.fade)
            rec.fade.targetItem = target
        _recs.push(rec)
        return rec
    }

    /// The row's shared reveal Translate, appended on first use. Returns null if
    /// the object can carry no transforms.
    function ensureTranslate(target) {
        if (!target.transform)
            return null
        for (var i = 0; i < target.transform.length; ++i)
            if (target.transform[i].objectName === "__karuReveal")
                return target.transform[i]
        var tr = translateComp.createObject(target)
        target.transform.push(tr)
        return tr
    }

    /// Drop records whose row (and so whose Translate) has been destroyed —
    /// e.g. after the panel changed and the Loader rebuilt it.
    function prune() {
        var alive = []
        for (var i = 0; i < _recs.length; ++i)
            if (_recs[i].target)
                alive.push(_recs[i])
        _recs = alive
    }

    /// The rows to cascade for `item`: unwrap lone container children (a card
    /// wrapping its content column) down to the visible rows, but never below a
    /// container that holds fewer than two real children.
    function collect(item) {
        var node = item
        for (var depth = 0; depth < 4; ++depth) {
            var kids = visibleChildren(node)
            if (kids.length === 1 && visibleChildren(kids[0]).length >= 2) {
                node = kids[0]
                continue
            }
            return kids
        }
        return visibleChildren(node)
    }

    /// A node's visible child Items, skipping any Repeater (and its delegates).
    function visibleChildren(node) {
        var out = []
        var kids = node.children || []
        var delegates = []
        for (var i = 0; i < kids.length; ++i) {
            var k = kids[i]
            if (isRepeater(k)) {
                if (k.itemAt) {
                    for (var d = 0; d < k.count; ++d)
                        delegates.push(k.itemAt(d))
                }
            }
        }
        for (var j = 0; j < kids.length; ++j) {
            var c = kids[j]
            if (isRepeater(c))
                continue
            if (delegates.indexOf(c) >= 0)
                continue
            if (c.visible === false)
                continue
            if (c.opacity === undefined || c.width === undefined)
                continue
            out.push(c)
        }
        return out
    }

    function isRepeater(o) {
        return o && typeof o.itemAt === "function" && typeof o.count === "number"
    }
}
