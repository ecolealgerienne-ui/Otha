import { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { useLanguage } from '../i18n';
import './legal.css';

interface LegalLayoutProps {
  children: ReactNode;
  title: string;
  subtitle?: string;
}

export function LegalLayout({ children, title, subtitle }: LegalLayoutProps) {
  const { t, isRTL } = useLanguage();

  return (
    <div className={`legal-page ${isRTL ? 'rtl' : ''}`}>
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
