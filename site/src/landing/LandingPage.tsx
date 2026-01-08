import { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useLanguage } from '../i18n';
import type { Language } from '../i18n';
import './landing.css';


export function LandingPage() {
  const navigate = useNavigate();
  const { language, setLanguage, t, isRTL } = useLanguage();
  const [isLanguageSelectorOpen, setIsLanguageSelectorOpen] = useState(false);
  const [selectedFeature, setSelectedFeature] = useState(0);

  // Features avec leurs écrans associés (traduits)
  const features = [
    { icon: 'fa-map-location-dot', title: t.features.findNearby.title, desc: t.features.findNearby.desc, screen: '/assets/img/screens/map.jpeg' },
    { icon: 'fa-paw', title: t.features.allPets.title, desc: t.features.allPets.desc, screen: '/assets/img/screens/home.jpeg' },
    { icon: 'fa-calendar-check', title: t.features.easyBooking.title, desc: t.features.easyBooking.desc, screen: '/assets/img/screens/home.jpeg' },
    { icon: 'fa-file-medical', title: t.features.healthRecord.title, desc: t.features.healthRecord.desc, screen: '/assets/img/screens/santé.jpeg' },
    { icon: 'fa-heart', title: t.features.adoption.title, desc: t.features.adoption.desc, screen: '/assets/img/screens/adopt.jpeg' },
    { icon: 'fa-house', title: t.features.daycare.title, desc: t.features.daycare.desc, screen: '/assets/img/screens/home.jpeg' },
  ];


  // État pour l'animation de scroll entre deux images
  const [previousFeature, setPreviousFeature] = useState<number | null>(null);
  const [isAnimating, setIsAnimating] = useState(false);

  // Gérer le changement de feature avec animation de scroll
  const handleFeatureClick = (index: number) => {
    if (index !== selectedFeature && !isAnimating) {
      setPreviousFeature(selectedFeature);
      setIsAnimating(true);
      setSelectedFeature(index);

      // Supprimer l'ancienne image après l'animation
      setTimeout(() => {
        setPreviousFeature(null);
        setIsAnimating(false);
      }, 500);
    }
  };

  // Charger FontAwesome et configurer le scroll personnalisé
  useEffect(() => {
    // Ajouter classe sur html pour le scroll
    document.documentElement.classList.add('landing-active');

    // Charger FontAwesome
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css';
    document.head.appendChild(link);

    // Gestionnaire de scroll personnalisé pour une animation lente
    const container = document.querySelector('.landing-page');
    let isScrolling = false;
    let scrollTimeout: ReturnType<typeof setTimeout>;

    const handleWheel = (e: WheelEvent) => {
      if (isScrolling) {
        e.preventDefault();
        return;
      }

      e.preventDefault();
      isScrolling = true;

      const sections = container?.querySelectorAll('.main, .showcase, .about, .download, .footer');
      if (!sections || !container) return;

      const currentScroll = (container as HTMLElement).scrollTop;
      const viewportHeight = window.innerHeight;

      // Trouver la section actuelle
      let currentIndex = 0;
      sections.forEach((section, index) => {
        const sectionTop = (section as HTMLElement).offsetTop;
        if (currentScroll >= sectionTop - viewportHeight / 2) {
          currentIndex = index;
        }
      });

      // Déterminer la direction et la cible
      let targetIndex = currentIndex;
      if (e.deltaY > 0 && currentIndex < sections.length - 1) {
        targetIndex = currentIndex + 1;
      } else if (e.deltaY < 0 && currentIndex > 0) {
        targetIndex = currentIndex - 1;
      }

      if (targetIndex !== currentIndex) {
        const targetSection = sections[targetIndex] as HTMLElement;
        const targetPosition = targetSection.offsetTop;
        const startPosition = (container as HTMLElement).scrollTop;
        const distance = targetPosition - startPosition;
        const duration = 1200; // Animation lente de 1.2 secondes
        let startTime: number | null = null;

        const easeInOutCubic = (t: number): number => {
          return t < 0.5
            ? 4 * t * t * t
            : 1 - Math.pow(-2 * t + 2, 3) / 2;
        };

        const animation = (currentTime: number) => {
          if (startTime === null) startTime = currentTime;
          const timeElapsed = currentTime - startTime;
          const progress = Math.min(timeElapsed / duration, 1);
          const easedProgress = easeInOutCubic(progress);

          (container as HTMLElement).scrollTop = startPosition + distance * easedProgress;

          if (timeElapsed < duration) {
            requestAnimationFrame(animation);
          } else {
            // Permettre un nouveau scroll après un délai
            scrollTimeout = setTimeout(() => {
              isScrolling = false;
            }, 100);
          }
        };

        requestAnimationFrame(animation);
      } else {
        isScrolling = false;
      }
    };

    container?.addEventListener('wheel', handleWheel as EventListener, { passive: false });

    return () => {
      document.documentElement.classList.remove('landing-active');
      document.head.removeChild(link);
      container?.removeEventListener('wheel', handleWheel as EventListener);
      clearTimeout(scrollTimeout);
    };
  }, []);

  // Gestion du clic sur le drapeau principal
  const handleMainFlagClick = () => {
    setIsLanguageSelectorOpen(!isLanguageSelectorOpen);
  };

  // Gestion du changement de langue
  const handleLanguageChange = (newLang: Language) => {
    setLanguage(newLang);
    setIsLanguageSelectorOpen(false);
  };

  // Scroll smooth vers une section avec animation lente personnalisée
  const scrollToSection = (sectionId: string) => {
    const element = document.getElementById(sectionId);
    const container = document.querySelector('.landing-page');
    if (element && container) {
      const targetPosition = element.offsetTop;
      const startPosition = container.scrollTop;
      const distance = targetPosition - startPosition;
      const duration = 1200; // Durée en ms - plus lent et fluide
      let startTime: number | null = null;

      // Easing function - easeInOutCubic pour une animation très fluide
      const easeInOutCubic = (t: number): number => {
        return t < 0.5
          ? 4 * t * t * t
          : 1 - Math.pow(-2 * t + 2, 3) / 2;
      };

      const animation = (currentTime: number) => {
        if (startTime === null) startTime = currentTime;
        const timeElapsed = currentTime - startTime;
        const progress = Math.min(timeElapsed / duration, 1);
        const easedProgress = easeInOutCubic(progress);

        container.scrollTop = startPosition + distance * easedProgress;

        if (timeElapsed < duration) {
          requestAnimationFrame(animation);
        }
      };

      requestAnimationFrame(animation);
    }
  };

  // Fonction pour afficher le texte avec retour à la ligne
  const renderWithLineBreaks = (text: string) => {
    return text.split('\n').map((line, index, array) => (
      <span key={index}>
        {line}
        {index < array.length - 1 && <br />}
      </span>
    ));
  };

  return (
    <div className={`landing-page ${isRTL ? 'rtl' : ''}`}>
      {/* Language Selector */}
      <div
        id="language-selector"
        className={isLanguageSelectorOpen ? 'open' : ''}
      >
        <button
          className="language-btn"
          onClick={handleMainFlagClick}
        >
          {language === 'fr' ? 'Français' : language === 'en' ? 'English' : 'العربية'}
        </button>

        <div className="language-dropdown">
          {language !== 'fr' && (
            <div
              className="language-option"
              onClick={() => handleLanguageChange('fr')}
            >
              Français
            </div>
          )}
          {language !== 'en' && (
            <div
              className="language-option"
              onClick={() => handleLanguageChange('en')}
            >
              English
            </div>
          )}
          {language !== 'ar' && (
            <div
              className="language-option"
              onClick={() => handleLanguageChange('ar')}
            >
              العربية
            </div>
          )}
        </div>
      </div>

      <main className="primary-main">
        {/* Navigation */}
        <nav className="navigation">
          <div className="nav-logo">
            <a
              href="#navigation"
              className="nav-item-link"
              onClick={(e) => { e.preventDefault(); scrollToSection('navigation'); }}
            >
              VEGECE
            </a>
          </div>

          <ul>
            <li className="nav-item">
              <a
                href="#showcase"
                className="nav-item-link"
                onClick={(e) => { e.preventDefault(); scrollToSection('showcase'); }}
              >
                {t.nav.presentation}
              </a>
            </li>
            <li className="nav-item">
              <a
                href="#about"
                className="nav-item-link"
                onClick={(e) => { e.preventDefault(); scrollToSection('about'); }}
              >
                {t.nav.about}
              </a>
            </li>
            <li className="nav-item">
              <a
                href="#download"
                className="nav-item-link"
                onClick={(e) => { e.preventDefault(); scrollToSection('download'); }}
              >
                {t.nav.download}
              </a>
            </li>
          </ul>

          <div
            className="nav-pro-login"
            style={{ cursor: 'pointer' }}
            onClick={() => navigate('/login')}
          >
            {t.nav.professional}
          </div>
        </nav>

        {/* Hero Section */}
        <div className="main" id="navigation">
          <span className="main-title">
            VEGECE
          </span>

          <span className="main-slogan">
            {t.hero.slogan}
          </span>

          <button
            className="main-btn scroll-arrow"
            onClick={() => scrollToSection('showcase')}
            aria-label={t.hero.scrollDown}
          >
            <i className="fa-solid fa-chevron-down"></i>
          </button>
        </div>

        {/* Showcase Section - Emotional */}
        <div className="showcase" id="showcase">
          <div className="showcase-image-container">
            <img
              src="/assets/img/fille-tenant-chat.png"
              alt="Pet owner"
              className="showcase-emotional-img"
            />
            <div className="showcase-image-overlay"></div>
          </div>

          <div className="showcase-content">
            <span className="showcase-headline">
              {renderWithLineBreaks(t.showcase.headline)}
            </span>

            <p className="showcase-subtext">
              {t.showcase.subtext}
            </p>

            <div className="showcase-benefits">
              <div className="showcase-benefit">
                <div className="benefit-icon">
                  <i className="fa-solid fa-bell"></i>
                </div>
                <div className="benefit-text">
                  <span className="benefit-title">{t.showcase.benefits.noForget.title}</span>
                  <span className="benefit-desc">{t.showcase.benefits.noForget.desc}</span>
                </div>
              </div>

              <div className="showcase-benefit">
                <div className="benefit-icon">
                  <i className="fa-solid fa-folder-open"></i>
                </div>
                <div className="benefit-text">
                  <span className="benefit-title">{t.showcase.benefits.centralized.title}</span>
                  <span className="benefit-desc">{t.showcase.benefits.centralized.desc}</span>
                </div>
              </div>

              <div className="showcase-benefit">
                <div className="benefit-icon">
                  <i className="fa-solid fa-clock"></i>
                </div>
                <div className="benefit-text">
                  <span className="benefit-title">{t.showcase.benefits.saveTime.title}</span>
                  <span className="benefit-desc">{t.showcase.benefits.saveTime.desc}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* About Section */}
        <div className="about" id="about">
          <div className="about-circle-container">
            {/* Phone au centre avec frame iPhone */}
            <div className="about-phone-center">
              <div className="iphone-frame">
                <img src="/assets/img/iphone.png" alt="iPhone Frame" className="iphone-border" />
                <div className="iphone-screen">
                  {/* Image précédente qui sort vers le haut */}
                  {previousFeature !== null && (
                    <img
                      key={`exit-${previousFeature}`}
                      src={features[previousFeature].screen}
                      alt={features[previousFeature].title}
                      className="screen-exit"
                    />
                  )}
                  {/* Image actuelle qui entre par le bas */}
                  <img
                    key={`enter-${selectedFeature}`}
                    src={features[selectedFeature].screen}
                    alt={features[selectedFeature].title}
                    className={isAnimating ? 'screen-enter' : ''}
                  />
                </div>
              </div>
            </div>

            {/* Features en cercle - rotation */}
            <div className="features-orbit">
              {features.map((feature, index) => (
                <div
                  key={index}
                  className={`about-feature feature-${index + 1} ${selectedFeature === index ? 'active' : ''}`}
                  onClick={() => handleFeatureClick(index)}
                >
                  <div className="feature-icon">
                    <i className={`fa-solid ${feature.icon}`}></i>
                  </div>
                  <div className="feature-content">
                    <span className="feature-title">{feature.title}</span>
                    <span className="feature-desc">{feature.desc}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Download Section */}
        <div className="download" id="download">
          <div className="download-content">
            <span className="download-label">{t.download.label}</span>
            <h2 className="download-title">
              {renderWithLineBreaks(t.download.title)}
            </h2>
            <p className="download-desc">
              {t.download.desc}
            </p>

            <div className="download-buttons">
              <a href="#" className="store-btn app-store">
                <i className="fa-brands fa-apple"></i>
                <div className="store-text">
                  <span className="store-label">{t.download.downloadOn}</span>
                  <span className="store-name">{t.download.appStore}</span>
                </div>
              </a>
              <a href="#" className="store-btn google-play">
                <i className="fa-brands fa-google-play"></i>
                <div className="store-text">
                  <span className="store-label">{t.download.availableOn}</span>
                  <span className="store-name">{t.download.googlePlay}</span>
                </div>
              </a>
            </div>

            <div className="download-stats">
              <div className="stat-item">
                <span className="stat-number">10K+</span>
                <span className="stat-label">{t.download.stats.downloads}</span>
              </div>
              <div className="stat-divider"></div>
              <div className="stat-item">
                <span className="stat-number">4.8</span>
                <span className="stat-label">{t.download.stats.rating}</span>
              </div>
              <div className="stat-divider"></div>
              <div className="stat-item">
                <span className="stat-number">500+</span>
                <span className="stat-label">{t.download.stats.vets}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <footer className="footer">
          <div className="footer-main">
            {/* Brand Section */}
            <div className="footer-brand">
              <div className="footer-logo">
                <i className="fa-solid fa-paw footer-logo-paw"></i>
                <span className="footer-name">VEGECE</span>
              </div>
              <p className="footer-tagline">
                {t.footer.tagline}
              </p>
            </div>

            {/* Navigation Section */}
            <div className="footer-nav-section">
              <div className="footer-nav-column">
                <span className="footer-nav-title">{t.footer.navigation}</span>
                <a href="#navigation" className="footer-nav-link" onClick={(e) => { e.preventDefault(); scrollToSection('navigation'); }}>
                  {t.footer.home}
                </a>
                <a href="#showcase" className="footer-nav-link" onClick={(e) => { e.preventDefault(); scrollToSection('showcase'); }}>
                  {t.nav.presentation}
                </a>
                <a href="#about" className="footer-nav-link" onClick={(e) => { e.preventDefault(); scrollToSection('about'); }}>
                  {t.nav.about}
                </a>
                <a href="#download" className="footer-nav-link" onClick={(e) => { e.preventDefault(); scrollToSection('download'); }}>
                  {t.nav.download}
                </a>
              </div>

              <div className="footer-nav-column">
                <span className="footer-nav-title">{t.footer.support}</span>
                <Link to="/support" className="footer-nav-link">{t.footer.helpCenter}</Link>
                <Link to="/support" className="footer-nav-link">{t.footer.contact}</Link>
                <Link to="/support" className="footer-nav-link">{t.footer.faq}</Link>
              </div>
            </div>

            {/* Social Section */}
            <div className="footer-social">
              <span className="footer-social-title">{t.footer.followUs}</span>
              <div className="footer-social-links">
                <a href="https://www.tiktok.com/@vegece.app" target="_blank" rel="noopener noreferrer" className="footer-social-link" aria-label="TikTok">
                  <i className="fa-brands fa-tiktok"></i>
                </a>
                <a href="https://www.facebook.com/profile.php?id=61584817777611" target="_blank" rel="noopener noreferrer" className="footer-social-link" aria-label="Facebook">
                  <i className="fa-brands fa-facebook-f"></i>
                </a>
                <a href="https://x.com/vegece_app?s=21" target="_blank" rel="noopener noreferrer" className="footer-social-link" aria-label="Twitter">
                  <i className="fa-brands fa-x-twitter"></i>
                </a>
                <a href="https://www.instagram.com/vegece.app/" target="_blank" rel="noopener noreferrer" className="footer-social-link" aria-label="Instagram">
                  <i className="fa-brands fa-instagram"></i>
                </a>
              </div>
            </div>
          </div>

          <div className="footer-divider"></div>

          <div className="footer-bottom">
            <span className="footer-copyright">{t.footer.copyright}</span>
            <div className="footer-legal">
              <Link to="/legal" className="footer-legal-link">{t.footer.legal}</Link>
              <Link to="/privacy" className="footer-legal-link">{t.footer.privacy}</Link>
              <Link to="/terms" className="footer-legal-link">{t.footer.terms}</Link>
            </div>
          </div>
        </footer>
      </main>
    </div>
  );
}

export default LandingPage;
