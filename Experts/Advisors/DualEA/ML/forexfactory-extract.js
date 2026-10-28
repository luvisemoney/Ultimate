(() => {
  const clean = s => (s || '').replace(/\s+/g, ' ').trim();
  const observed = Math.floor(Date.now() / 1000);
  const title = document.title;
  if (/just a moment|un instant|attention required|security verification/i.test(title) ||
      document.querySelector('iframe[src*="challenges.cloudflare.com"]'))
    return { status: 'HUMAN_VERIFICATION_REQUIRED', title, url: location.href };
  if (location.hostname !== 'www.forexfactory.com') return { status: 'UNEXPECTED_ORIGIN' };
  const result = {status: 'OK', source_url: location.href, observed_utc: observed};
  if (location.pathname === '/news') {
    const records = new Map();
    for (const component of document.querySelectorAll('news-block-component[data-items]')) {
      for (const item of JSON.parse(component.getAttribute('data-items'))) {
        if (!item.id || !item.title || !item.dateline || !item.url) continue;
        const url = new URL(item.url, location.origin);
        if (url.origin !== location.origin) continue;
        const impact = /high/i.test(item.impact_svg_id || item.impact) ? 3 :
          /medium/i.test(item.impact_svg_id || item.impact) ? 2 : /low/i.test(item.impact_svg_id || item.impact) ? 1 : 0;
        records.set(String(item.id), {id: String(item.id), published_utc: Number(item.dateline),
          headline: clean(item.title), source_url: url.href, publisher: clean(item.source), impact,
          comment_count: Number.isFinite(Number(item.comments)) ? Number(item.comments) : null});
      }
    }
    result.news = [...records.values()];
    if (!result.news.length) result.status = 'PARSE_EMPTY';
  } else if (location.pathname === '/forums') {
    const records = new Map();
    for (const row of document.querySelectorAll('.flexposts__item.flexposts__post')) {
      const link = row.querySelector('.flexposts__title a[href*="/thread/post/"]');
      const text = clean(row.querySelector('.flexposts__preview')?.textContent);
      if (!link || !text) continue;
      const id = link.href.match(/\/thread\/post\/(\d+)/)?.[1];
      if (!id) continue;
      const stamp = row.querySelector('[data-timestamp]')?.getAttribute('data-timestamp');
      records.set(id, {id, source_url: link.href, text,
        thread_title: clean(row.querySelector('.flexposts__caption .title')?.textContent),
        reply_metadata: clean(link.textContent),
        published_utc: stamp && /^\d+$/.test(stamp) ? Number(stamp) : null,
        timestamp_precision: stamp ? 'site_epoch' : 'relative_text_only',
        classification: 'PUBLIC_OPINION_NOT_VERIFIED_FACT'});
    }
    result.forum = [...records.values()];
    if (!result.forum.length) result.status = 'PARSE_EMPTY';
  } else if (location.pathname === '/trades') {
    result.trade_activity = [...document.querySelectorAll('.trades_activity__row')].map(row => {
      const overview = clean(row.querySelector('.trades_activity__overview')?.textContent);
      const direction = clean(row.querySelector('.trades_activity__direction')?.textContent);
      const info = row.querySelector('.trades_activity__info');
      const link = info?.querySelector('a');
      const parts = overview.match(/^(.*?)\s+(BUY|SELL)\s+(.*)$/i);
      const stamp = Number(info?.getAttribute('data-timestamp'));
      return {id: row.id, symbol_raw: parts ? parts[1] : null, transaction_side: direction,
        displayed_price_raw: parts ? parts[3] : null, action: clean(link?.textContent),
        published_utc: Number.isFinite(stamp) && stamp > 0 ? stamp : null,
        source_url: link?.href || location.href,
        trader: clean(row.querySelector('.usernamedisplay__username')?.textContent),
        displayed_return_raw: clean(row.querySelector('.trades_activity__cell--return')?.textContent),
        classification: 'PUBLIC_SAMPLE_NOT_MARKET_ORDER_FLOW_OR_TRAINING_LABEL'};
    }).filter(row => row.id && row.symbol_raw && row.source_url);
    result.positioning = [...document.querySelectorAll('.trades_positions__row')].map(row => {
      const chart = row.querySelector('.trades_position__chart--traders');
      const longText = clean(chart?.querySelector('.trades_position__label--long')?.textContent);
      const shortText = clean(chart?.querySelector('.trades_position__label--short')?.textContent);
      const lp = longText.match(/([\d.]+)%/), sp = shortText.match(/([\d.]+)%/);
      const lc = longText.match(/([\d,]+)\s+Traders/i), sc = shortText.match(/([\d,]+)\s+Traders/i);
      return {instrument: clean(row.querySelector('a.currency')?.textContent),
        long_percent: lp ? Number(lp[1]) : null, short_percent: sp ? Number(sp[1]) : null,
        long_traders: lc ? Number(lc[1].replace(/,/g, '')) : null,
        short_traders: sc ? Number(sc[1].replace(/,/g, '')) : null,
        observed_utc: observed, source_url: location.href, publication_time: null,
        classification: 'FOREX_FACTORY_SAMPLE_NOT_TOTAL_MARKET_POSITIONING'};
    }).filter(row => row.instrument && row.long_percent !== null && row.short_percent !== null);
    if (!result.trade_activity.length || !result.positioning.length) result.status = 'PARSE_EMPTY';
  } else result.status = 'UNSUPPORTED_PAGE';
  return result;
})()
