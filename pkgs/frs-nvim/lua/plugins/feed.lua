local root_feeds = {
  "https://feeds.allenpike.com/feed/",
  "https://daringfireball.net/feeds/json",
  "https://netnewswire.blog/feed.json",
  "https://pluralistic.net/feed/",
  "https://xkcd.com/atom.xml",
}

local crypto_feeds = {
  "https://www.paradigm.xyz/rss/feed.xml",
  "http://vitalik.ca/feed.xml",
}

local rust_feeds = {
  "https://fasterthanli.me/index.xml",
  "https://blog.rust-lang.org/inside-rust/feed.xml",
  "https://blog.m-ou.se/index.xml",
  "http://blog.rust-lang.org/feed.xml",
  "https://sabrinajewson.org/blog/feed.xml",
}

local programming_feeds = {
  "https://amasad.me/rss",
  "http://andrewkelley.me/rss.xml",
  "https://briansmith.org/feed.atom",
  "https://world.hey.com/dhh/feed.atom",
  "https://inessential.com/xml/rss.xml",
  "https://blog.janestreet.com/feed.xml",
  "https://jalammar.github.io/feed.xml",
  "https://jvns.ca/atom.xml",
  "https://carolchen.me/blog/atom.xml",
  "http://tratt.net/laurie/tech_articles/rss",
  "https://kristoff.it/index.xml",
  "https://mcyoung.xyz/atom.xml",
  "http://feeds.feedburner.com/mitchellh",
  "https://ratfactor.com/atom.xml",
  "https://redvice.org/feed.xml",
  "https://tinyclouds.org:443/feed",
  "https://media.rss.com/scrapingbits/feed.xml",
  "https://stephanango.com/feed.xml",
  "http://www.stephendiehl.com/feed.rss",
  "https://fly.io/blog/feed.xml",
  "https://thume.ca/atom.xml",
  "https://sillycross.github.io/atom.xml",
  "https://v8.dev/blog.atom",
  "https://without.boats/index.xml",
  "https://xeiaso.net/blog.rss",
}

programming_feeds.rust = rust_feeds
root_feeds.crypto = crypto_feeds
root_feeds.programming = programming_feeds

return {
  {
    "neo451/feed.nvim",
    cmd = "Feed",
    opts = {
      progress = { backend = "fidget" },
      feeds = root_feeds,
    },
    dependencies = {
      {
        "folke/snacks.nvim",
        opts = { image = { enabled = true } },
      },
    },
  },
}
