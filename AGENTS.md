# Moonfind agent guide

Moonfind is a MoonBit-first MoonSuite domain pack. Keep general research
contracts in `research/`; arXiv transport in `arxiv/`; humanoid-robotics
semantics in `humanoid/`; Moontown scenario projection in `moontown/`; and the
Rabbita client in `ui/rabbita-moonfind/`.

MoonClaw is the only agent runtime. Moonfind may construct reviewed work
packets but must not call model providers directly. MoonFlow owns generic
activation state; MoonBook owns durable reviewed memory and Three Gap records.

Do not add Python. Use `moon ide` for API discovery, `moon check` while
developing, and `moon info` before committing public API changes.
