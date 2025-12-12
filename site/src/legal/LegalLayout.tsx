import { ReactNode, useState } from 'react';
import { Link } from 'react-router-dom';
import { useLanguage } from '../i18n';
import type { Language } from '../i18n';
import './legal.css';

// Configuration des drapeaux
const FLAGS: Record<Language, { lang: Language; imgSrc: string; altText: string; dataImg: string }> = {
  fr: {
    lang: 'fr',
    imgSrc: '/assets/img/french.png',
    altText: 'Français',
    dataImg: 'france'
  },
  en: {
    lang: 'en',
    imgSrc: '/assets/img/english.png',
    altText: 'English',
    dataImg: 'uk'
  },
  ar: {
    lang: 'ar',
    imgSrc: '/assets/img/algeria.png',
    altText: 'العربية',
    dataImg: 'algeria'
  }
};

interface LegalLayoutProps {
  children: ReactNode;
  title: string;
  subtitle?: string;
}

export function LegalLayout({ children, title, subtitle }: LegalLayoutProps) {
  const { language, setLanguage, t, isRTL } = useLanguage();
  const [isLanguageSelectorOpen, setIsLanguageSelectorOpen] = useState(false);

  // Obtenir les drapeaux disponibles (excluant la langue actuelle)
  const getOtherFlags = () => {
    return Object.values(FLAGS).filter(flag => flag.lang !== language);
  };

  return (
    <div className={`legal-page ${isRTL ? 'rtl' : ''}`}>
      {/* Language Selector */}
      <div
        id="language-selector"
        className={`legal-language-selector ${isLanguageSelectorOpen ? 'open' : ''}`}
      >
        <div
          className="flag-circle main-flag"
          onClick={() => setIsLanguageSelectorOpen(!isLanguageSelectorOpen)}
        >
          <img src={FLAGS[language].imgSrc} alt={FLAGS[language].altText} />
        </div>

        <div className="sub-flags">
          {getOtherFlags().map((flag) => (
            <div
              key={flag.lang}
              className="flag-circle sub-flag"
              onClick={() => {
                setLanguage(flag.lang);
                setIsLanguageSelectorOpen(false);
              }}
            >
              <img src={flag.imgSrc} alt={flag.altText} />
            </div>
          ))}
        </div>
      </div>

      {/* Navigation */}
      <nav className="legal-navigation">
        <Link to="/" className="legal-nav-logo">
          VEGECE
        </Link>
        <Link to="/" className="legal-nav-back">
          <i className="fa-solid fa-arrow-left"></i>
          <span>{t.footer.home}</span>
        </Link>
      </nav>

      {/* Header */}
      <header className="legal-header">
        <div className="legal-header-content">
          <h1 className="legal-title">{title}</h1>
          {subtitle && <p className="legal-subtitle">{subtitle}</p>}
        </div>
        <div className="legal-header-decoration"></div>
      </header>

      {/* Content */}
      <main className="legal-content">
        <div className="legal-container">
          {children}
        </div>
      </main>

      {/* Footer */}
      <footer className="legal-footer">
        <div className="legal-footer-content">
          <div className="legal-footer-brand">
            <i className="fa-solid fa-paw"></i>
            <span>VEGECE</span>
          </div>
          <div className="legal-footer-links">
            <Link to="/legal">{t.footer.legal}</Link>
            <Link to="/privacy">{t.footer.privacy}</Link>
            <Link to="/terms">{t.footer.terms}</Link>
            <Link to="/support">{t.footer.support}</Link>
          </div>
          <p className="legal-footer-copyright">{t.footer.copyright}</p>
        </div>
      </footer>
    </div>
  );
}

export default LegalLayout;
