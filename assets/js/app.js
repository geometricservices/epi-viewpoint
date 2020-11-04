// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.sass";

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"

//
// User menu
//
document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("#user-menu").forEach((userMenu) => {
    userMenu.addEventListener("click", (event) => {
      let target = document.querySelector("#user-menu-list");
      target.style.display = target.style.display === "block" ? "none" : "block";
    });
  });

  document.addEventListener("click", (e) => {
    document.querySelectorAll("#user-menu").forEach((userMenu) => {
      if (!userMenu.contains(e.target)) {
        document.querySelectorAll("[role=menu]").forEach((menu) => {
          if (menu.style.display === "block") {
            menu.style.display = "none";
          }
        });
      }
    });
  });
});

//
// LiveView
//
import "phoenix_html";
import { Socket } from "phoenix";
import NProgress from "nprogress";
import { LiveSocket, Browser } from "phoenix_live_view";

let Hooks = {};

Hooks.AutocompleteInput = {
  mounted() {
    this.el.addEventListener("keyup", (e) => {
      switch (e.code) {
        case "ArrowLeft":
        case "ArrowRight":
        case "ArrowUp":
        case "Escape":
        case "Shift":
        case "Space":
          // ignore
          break;

        case "ArrowDown":
          let listbox = this.el.parentNode.querySelector("[role=listbox]");
          let firstItem = listbox.children[0];
          firstItem.focus();
          firstItem.setAttribute("aria-selected", "true");
          break;

        default:
          break;
      }
    });
  }
};

Hooks.AutocompleteList = {
  mounted() {
    document.addEventListener("keydown", (e) => {
      let listbox = document.querySelector("[role=listbox]");
      if (listbox && listbox.hasChildNodes()) {
        if (["ArrowUp", "ArrowDown"].indexOf(e.code) > -1) {
          e.preventDefault();
        }
      }
    });

    document.addEventListener("click", (e) => {
      if (e.target.getAttribute("role") !== "option") {
        while (this.el.firstChild) {
          this.el.removeChild(this.el.firstChild);
        }
      }
    });

    this.el.addEventListener("keyup", (e) => {
      let select = function (listbox, direction) {
        let selectedItem = listbox.querySelector("[aria-selected=true]");
        let toSelect;

        if (direction === "down") {
          toSelect = selectedItem.nextElementSibling;
        } else {
          toSelect = selectedItem.previousElementSibling;
        }

        if (toSelect) {
          selectedItem.setAttribute("aria-selected", "false");
          toSelect.focus();
          toSelect.setAttribute("aria-selected", "true");
        }

        e.preventDefault();
        e.stopPropagation();
      };

      switch (e.code) {
        case "ArrowDown":
          select(this.el, "down");
          break;

        case "ArrowUp":
          select(this.el, "up");
          break;

        case "Enter":
          this.el.querySelector("[aria-selected=true]").click();
          break;

        default:
          break;
      }
    });
  }
};

Hooks.Multiselect = {
  mounted() {}
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken }
});

window.addEventListener("phx:page-loading-stop", (info) => {
  let hashEl = Browser.getHashTargetEl(window.location.hash);
  if (hashEl) {
    hashEl.scrollIntoView();
  }
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
