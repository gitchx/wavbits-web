const links = {
  mixing: 'https://nekomixing.vercel.app',
  recording: 'https://utattemita.wavbits.com',
  dsp: 'https://dsp.wavbits.com',
  blog: 'https://blog.wavbits.com',
  archive: 'https://somak.netlify.app',
};

function Arrow() {
  return <span className="arrow" aria-hidden="true">↗</span>;
}

export default function Home() {
  return (
    <div className="page">
      <header className="site-header">
        <a className="brand" href="/" aria-label="wavbits ホーム">wavbits</a>
        <p className="tagline">music, audio &amp; software</p>
      </header>
      <main>
        <section className="section" aria-labelledby="vocal-mixing-title">
          <div className="section-heading">
            <h1 id="vocal-mixing-title">Vocal Mixing</h1>
            <p lang="ja">歌ってみたミックス</p>
          </div>
          <nav className="link-list" aria-label="Vocal Mixing services">
            <a className="link-item" href={links.mixing}>
              <span><span className="link-title">Mixing</span><span className="link-description" lang="ja">ミックスのみ</span></span>
              <Arrow />
            </a>
            <a className="link-item" href={links.recording}>
              <span><span className="link-title">Recording &amp; Mixing</span><span className="link-description" lang="ja">レコーディングとミックス</span></span>
              <Arrow />
            </a>
          </nav>
        </section>
        <section className="section" aria-labelledby="dsp-title">
          <div className="section-heading"><h2 id="dsp-title">DSP</h2><p>Audio DSP / Plugin Development</p></div>
          <a className="link-item" href={links.dsp}><span className="link-title">dsp.wavbits.com</span><Arrow /></a>
        </section>
        <section className="section" aria-labelledby="blog-title">
          <div className="section-heading"><h2 id="blog-title">Blog</h2><p>Music Production / Development</p></div>
          <a className="link-item" href={links.blog}><span className="link-title">blog.wavbits.com</span><Arrow /></a>
        </section>
        <section className="section archived" aria-labelledby="archived-title">
          <div className="section-heading"><h2 id="archived-title">Archived</h2><p>Past projects and experiments</p></div>
          <a className="link-item" href={links.archive}>
            <span><span className="link-title">Software</span><span className="link-description">Max/MSP and other projects</span></span>
            <Arrow />
          </a>
        </section>
      </main>
      <footer><p>© wavbits</p></footer>
    </div>
  );
}
