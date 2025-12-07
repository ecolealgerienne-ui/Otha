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

  // Charger FontAwesome et configurer le HTML
  useEffect(() => {
    // Ajouter classe sur html pour le scroll
    document.documentElement.classList.add('landing-active');

    // Charger FontAwesome
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css';
    document.head.appendChild(link);

    return () => {
      document.documentElement.classList.remove('landing-active');
      document.head.removeChild(link);
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

  // Scroll smooth vers une section
  const scrollToSection = (sectionId: string) => {
    const element = document.getElementById(sectionId);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
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
            SLOGAN
          </span>

          <button
            className="main-btn scroll-arrow"
            onClick={() => scrollToSection('showcase')}
            aria-label="Défiler vers le bas"
          >
            <i className="fa-solid fa-chevron-down"></i>
          </button>
        </div>

        {/* Showcase Section */}
        <div className="showcase" id="showcase">
          <div className="page-selector page-selector-pos">
            <div className="selector-bg">
              <div className="selector-active"></div>
              <div className="selector-case"></div>
              <div className="selector-case"></div>
            </div>
          </div>

          <div className="showcase-img">
            <img src="/assets/img/phone.png" alt="" className="showcase-img-size" />
          </div>

          <div className="showcase-desc">
            <span className="showcase-desc-title">
              Titre explication page 1
            </span>
            <span className="showcase-desc-text">
              Lorem ipsum dolor sit amet, consectetur adipiscing elit.<br />
              Donec pharetra diam non tempor bibendum.<br />
              In vestibulum, magna eu blandit viverra, dui arcu vestibulum nisl,<br />
              id pretium tellus neque vitae diam.<br />
              Ut tristique felis ac maximus ullamcorper.<br />
              Fusce lacinia tellus ut ligula viverra blandit.
            </span>
          </div>
        </div>

        {/* About Section */}
        <div className="about" id="about">
          <div className="about-grid">
            <div className="page-selector page-selector-pos-2">
              <div className="selector-bg">
                <div className="selector-case"></div>
                <div className="selector-active"></div>
                <div className="selector-case"></div>
              </div>
            </div>

            <div className="div2">
              <i className="fa-solid fa-magnifying-glass grid-icon"></i>
              <span className="about-grid-text">
                Powerful Research
              </span>
            </div>
            <div className="div3">
              <i className="fa-solid fa-paw grid-icon"></i>
              <span className="about-grid-text">
                For all pet
              </span>
            </div>
            <div className="div4">
              <i className="fa-solid fa-hospital grid-icon"></i>
              <span className="about-grid-text">
                Find Best Practician
              </span>
            </div>
            <div className="div5">
              <i className="fa-solid fa-folder grid-icon"></i>
              <span className="about-grid-text">
                Pet medical history
              </span>
            </div>
            <div className="div6">
              <i className="fa-solid fa-dog grid-icon"></i>
              <span className="about-grid-text">
                Adoption
              </span>
            </div>
          </div>
        </div>

        {/* Download Section */}
        <div className="download" id="download">
          <span className="download-title">
            Titre explication page 3
          </span>
          <span className="download-desc">
            Lorem ipsum dolor sit amet, consectetur adipiscing elit.<br />
            Donec pharetra diam non tempor bibendum.<br />
            In vestibulum, magna eu blandit viverra, dui arcu vestibulum nisl,<br />
            id pretium tellus neque vitae diam.<br />
            Ut tristique felis ac maximus ullamcorper.<br />
            Fusce lacinia tellus ut ligula viverra blandit.
          </span>
          <button className="download-btn">
            Download App
          </button>
          <span className="download-os">
            iOS, Android
          </span>
        </div>

        {/* Footer */}
        <footer className="footer">
          <div className="footer-side-1">
            <div className="footer-logo">
              <i className="fa-solid fa-paw footer-logo-paw"></i>
            </div>
            <span className="footer-name">
              VEGECE<br />
              2025©
            </span>
          </div>

          <div className="footer-side-2">
            <ul className="footer-nav">
              <li className="footer-nav-item">
                <a
                  href="#navigation"
                  className="nav-item-link"
                  onClick={(e) => { e.preventDefault(); scrollToSection('navigation'); }}
                >
                  Acceuil
                </a>
              </li>
              <li className="footer-nav-item">
                <a
                  href="#showcase"
                  className="nav-item-link"
                  onClick={(e) => { e.preventDefault(); scrollToSection('showcase'); }}
                >
                  Présentation
                </a>
              </li>
              <li className="footer-nav-item">
                <a
                  href="#about"
                  className="nav-item-link"
                  onClick={(e) => { e.preventDefault(); scrollToSection('about'); }}
                >
                  A propos
                </a>
              </li>
              <li className="footer-nav-item">
                <a
                  href="#download"
                  className="nav-item-link"
                  onClick={(e) => { e.preventDefault(); scrollToSection('download'); }}
                >
                  Téléchargement
                </a>
              </li>
            </ul>
          </div>

          <div className="footer-side-3">
            <ul className="footer-nav-social">
              <li className="footer-nav-social">
                <a href="#" className="nav-item-link">
                  <i className="fa-brands fa-tiktok"></i>
                </a>
              </li>
              <li className="footer-nav-social">
                <a href="#" className="nav-item-link">
                  <i className="fa-brands fa-facebook"></i>
                </a>
              </li>
              <li className="footer-nav-social">
                <a href="#" className="nav-item-link">
                  <i className="fa-brands fa-x-twitter"></i>
                </a>
              </li>
              <li className="footer-nav-social">
                <a href="#" className="nav-item-link">
                  <i className="fa-brands fa-instagram"></i>
                </a>
              </li>
            </ul>
          </div>
        </footer>
      </main>
    </div>
  );
}

export default LandingPage;
