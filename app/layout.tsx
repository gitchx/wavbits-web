import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'wavbits — music, audio & software',
  description: 'wavbitsの音楽、ボーカルミックス、オーディオDSP、ソフトウェア開発活動への入口。',
  openGraph: { title: 'wavbits — music, audio & software', description: 'Music, vocal mixing, audio DSP and software development.', type: 'website' },
  twitter: { card: 'summary', title: 'wavbits — music, audio & software', description: 'Music, vocal mixing, audio DSP and software development.' },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="ja"><body>{children}</body></html>;
}
