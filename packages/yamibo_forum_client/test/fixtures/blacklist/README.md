# Desktop web-blacklist fixture

`desktop.html` is a reduced, sanitized reconstruction of the logged-in desktop
blacklist page supplied by the user. All user ids, names, avatar URLs and the
formhash are synthetic; no account name, cookie, session token, private content
or original response body is stored.

The fixture keeps the observed request contract:

- form `name="blackform"` posting to
  `home.php?mod=spacecp&ac=friend&op=blacklist&start=`;
- text field `username` (the exact server username, prefilled in the browser);
- submit button `blacklistsubmit_btn=true`;
- hidden `blacklistsubmit=true` and the session `formhash`;
- list container `#friend_ul` with `li#friend_<uid>_li` rows.

The adapter tests also synthesize the two observed response families from the
Discuz `showmessage` shell: a quick-forward redirect to
`home.php?mod=space&uid=<actor>&do=friend&view=blacklist&quickforward=1`, and an
alert page. Success is never accepted from the response alone: the command
re-reads the complete list and requires the target uid and username. Error,
login and unrecognized pages are mapped per adapter tests; unproven sent
requests stay `outcomeUnknown`.
