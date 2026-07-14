// esbuild automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "config.exs".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view";

let hooks = {}

// Plays the recording's audio in the transcript editor, seeking to a segment's
// start when the server pushes "play-segment-audio" (clicking a segment). The
// click is a user gesture, so browser autoplay policy allows play().
hooks.SegmentAudio = {
  mounted() {
    this.el.src = this.el.dataset.src
    this.handleEvent("play-segment-audio", ({ at }) => {
      this.el.currentTime = at
      this.el.play().catch(() => {})
    })
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken }, hooks })

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket
