import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import './landing.css';

// Types pour le sélecteur de langue
interface LanguageData {
  lang: string;
  imgSrc: string;
  altText: string;
  dataImg: string;
}

export function LandingPage() {
  const navigate = useNavigate();
  const [isLanguageSelectorOpen, setIsLanguageSelectorOpen] = useState(false);
  const [selectedFeature, setSelectedFeature] = useState(0);

  // Features avec leurs écrans associés
  const features = [
    { icon: 'fa-map-location-dot', title: 'Trouvez autour de vous', desc: 'Vétérinaires, garderies, pet shops près de chez vous', screen: '/assets/img/screens/map.jpeg' },
    { icon: 'fa-paw', title: 'Tous vos animaux', desc: 'Chiens, chats, NAC... gérez tous vos compagnons', screen: '/assets/img/screens/home.jpeg' },
    { icon: 'fa-calendar-check', title: 'Rendez-vous facile', desc: 'Réservez en quelques clics chez votre vétérinaire', screen: '/assets/img/screens/home.jpeg' },
    { icon: 'fa-file-medical', title: 'Carnet de santé', desc: 'Vaccins, ordonnances, historique médical centralisé', screen: '/assets/img/screens/santé.jpeg' },
    { icon: 'fa-heart', title: 'Adoption', desc: 'Trouvez votre futur compagnon ou proposez à l\'adoption', screen: '/assets/img/screens/adopt.jpeg' },
    { icon: 'fa-house', title: 'Garderie', desc: 'Trouvez une garderie de confiance pour vos absences', screen: '/assets/img/screens/home.jpeg' },
  ];

  // État pour les drapeaux
  const [mainFlag, setMainFlag] = useState<LanguageData>({
    lang: 'fr',
    imgSrc: '/assets/img/french.png',
    altText: 'Drapeau Français',
    dataImg: 'france'
  });

  const [subFlags, setSubFlags] = useState<LanguageData[]>([
    {
      lang: 'en',
      imgSrc: '/assets/img/english.png',
      altText: 'Drapeau Anglais',
      dataImg: 'uk'
    },
    {
      lang: 'dz',
      imgSrc: '/assets/img/algeria.png',
      altText: 'Drapeau Algérien',
      dataImg: 'algeria'
    }
  ]);

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
  const handleSubFlagClick = (index: number) => {
    const clickedSubFlag = subFlags[index];
    const currentMainFlag = mainFlag;

    // Swap les drapeaux
    setMainFlag(clickedSubFlag);

    const newSubFlags = [...subFlags];
    newSubFlags[index] = currentMainFlag;
    setSubFlags(newSubFlags);

    // Fermer le sélecteur
    setIsLanguageSelectorOpen(false);

    console.log(`Nouvelle langue sélectionnée : ${clickedSubFlag.lang}`);
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

  return (
    <div className="landing-page">
      {/* Language Selector */}
      <div
        id="language-selector"
        className={isLanguageSelectorOpen ? 'open' : ''}
      >
        <div
          className="flag-circle main-flag"
          data-lang={mainFlag.lang}
          data-img={mainFlag.dataImg}
          onClick={handleMainFlagClick}
        >
          <img src={mainFlag.imgSrc} alt={mainFlag.altText} />
        </div>

        <div className="sub-flags">
          {subFlags.map((flag, index) => (
            <div
              key={flag.lang}
              className="flag-circle sub-flag"
              data-lang={flag.lang}
              data-img={flag.dataImg}
              onClick={() => handleSubFlagClick(index)}
            >
              <img src={flag.imgSrc} alt={flag.altText} />
            </div>
          ))}
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
                Présentation
              </a>
            </li>
            <li className="nav-item">
              <a
                href="#about"
                className="nav-item-link"
                onClick={(e) => { e.preventDefault(); scrollToSection('about'); }}
              >
                A propos
              </a>
            </li>
            <li className="nav-item">
              <a
                href="#download"
                className="nav-item-link"
                onClick={(e) => { e.preventDefault(); scrollToSection('download'); }}
              >
                Téléchargement
              </a>
            </li>
          </ul>

          <div
            className="nav-pro-login"
            style={{ cursor: 'pointer' }}
            onClick={() => navigate('/login')}
          >
            Vous êtes un professionnel ?
          </div>
        </nav>

        {/* Hero Section */}
        <div className="main" id="navigation">
          <span className="main-title">
            VEGECE
          </span>

          <span className="main-slogan">
            La santé de votre animal, simplifiée
          </span>

          <button
            className="main-btn scroll-arrow"
            onClick={() => scrollToSection('showcase')}
            aria-label="Défiler vers le bas"
          >
            <i className="fa-solid fa-chevron-down"></i>
          </button>
        </div>

        {/* Showcase Section - Emotional */}
        <div className="showcase" id="showcase">
          <div className="showcase-image-container">
            <img
              src="/assets/img/fille-tenant-chat.png"
              alt="Propriétaire avec son animal"
              className="showcase-emotional-img"
            />
            <div className="showcase-image-overlay"></div>
          </div>

          <div className="showcase-content">
            <span className="showcase-headline">
              Parce qu'ils comptent<br />sur vous
            </span>

            <p className="showcase-subtext">
              Offrez-leur le meilleur avec une gestion simplifiée de leur santé et bien-être.
            </p>

            <div className="showcase-benefits">
              <div className="showcase-benefit">
                <div className="benefit-icon">
                  <i className="fa-solid fa-bell"></i>
                </div>
                <div className="benefit-text">
                  <span className="benefit-title">Fini les oublis</span>
                  <span className="benefit-desc">Rappels automatiques pour les vaccins et rendez-vous</span>
                </div>
              </div>

              <div className="showcase-benefit">
                <div className="benefit-icon">
                  <i className="fa-solid fa-folder-open"></i>
                </div>
                <div className="benefit-text">
                  <span className="benefit-title">Tout centralisé</span>
                  <span className="benefit-desc">Carnet de santé, ordonnances, historique médical</span>
                </div>
              </div>

              <div className="showcase-benefit">
                <div className="benefit-icon">
                  <i className="fa-solid fa-clock"></i>
                </div>
                <div className="benefit-text">
                  <span className="benefit-title">Gagnez du temps</span>
                  <span className="benefit-desc">Trouvez un vétérinaire et réservez en 30 secondes</span>
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
            <span className="download-label">Téléchargement</span>
            <h2 className="download-title">
              Prêt à simplifier<br />la vie de vos animaux ?
            </h2>
            <p className="download-desc">
              Rejoignez des milliers de propriétaires qui font confiance à VEGECE pour prendre soin de leurs compagnons.
            </p>

            <div className="download-buttons">
              <a href="#" className="store-btn app-store">
                <i className="fa-brands fa-apple"></i>
                <div className="store-text">
                  <span className="store-label">Télécharger sur</span>
                  <span className="store-name">App Store</span>
                </div>
              </a>
              <a href="#" className="store-btn google-play">
                <i className="fa-brands fa-google-play"></i>
                <div className="store-text">
                  <span className="store-label">Disponible sur</span>
                  <span className="store-name">Google Play</span>
                </div>
              </a>
            </div>

            <div className="download-stats">
              <div className="stat-item">
                <span className="stat-number">10K+</span>
                <span className="stat-label">Téléchargements</span>
              </div>
              <div className="stat-divider"></div>
              <div className="stat-item">
                <span className="stat-number">4.8</span>
                <span className="stat-label">Note moyenne</span>
              </div>
              <div className="stat-divider"></div>
              <div className="stat-item">
                <span className="stat-number">500+</span>
                <span className="stat-label">Vétérinaires</span>
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
                La santé de vos animaux, simplifiée. Tout ce dont vous avez besoin, en une seule application.
              </p>
            </div>

            {/* Navigation Section */}
            <div className="footer-nav-section">
              <div className="footer-nav-column">
                <span className="footer-nav-title">Navigation</span>
                <a href="#navigation" className="footer-nav-link" onClick={(e) => { e.preventDefault(); scrollToSection('navigation'); }}>
                  Accueil
                </a>
                <a href="#showcase" className="footer-nav-link" onClick={(e) => { e.preventDefault(); scrollToSection('showcase'); }}>
                  Présentation
                </a>
                <a href="#about" className="footer-nav-link" onClick={(e) => { e.preventDefault(); scrollToSection('about'); }}>
                  À propos
                </a>
                <a href="#download" className="footer-nav-link" onClick={(e) => { e.preventDefault(); scrollToSection('download'); }}>
                  Téléchargement
                </a>
              </div>

              <div className="footer-nav-column">
                <span className="footer-nav-title">Support</span>
                <a href="#" className="footer-nav-link">Centre d'aide</a>
                <a href="#" className="footer-nav-link">Contact</a>
                <a href="#" className="footer-nav-link">FAQ</a>
              </div>
            </div>

            {/* Social Section */}
            <div className="footer-social">
              <span className="footer-social-title">Suivez-nous</span>
              <div className="footer-social-links">
                <a href="#" className="footer-social-link" aria-label="TikTok">
                  <i className="fa-brands fa-tiktok"></i>
                </a>
                <a href="#" className="footer-social-link" aria-label="Facebook">
                  <i className="fa-brands fa-facebook-f"></i>
                </a>
                <a href="#" className="footer-social-link" aria-label="Twitter">
                  <i className="fa-brands fa-x-twitter"></i>
                </a>
                <a href="#" className="footer-social-link" aria-label="Instagram">
                  <i className="fa-brands fa-instagram"></i>
                </a>
              </div>
            </div>
          </div>

          <div className="footer-divider"></div>

          <div className="footer-bottom">
            <span className="footer-copyright">© 2025 VEGECE. Tous droits réservés.</span>
            <div className="footer-legal">
              <a href="#" className="footer-legal-link">Mentions légales</a>
              <a href="#" className="footer-legal-link">Politique de confidentialité</a>
              <a href="#" className="footer-legal-link">CGU</a>
            </div>
          </div>
        </footer>
      </main>
    </div>
  );
}

export default LandingPage;
