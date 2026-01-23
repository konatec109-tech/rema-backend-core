/* --- wrap/OS CORE SYSTEM --- */

document.addEventListener('DOMContentLoaded', () => {
    console.log("wrap/OS Systems: ONLINE");

    // 1. EFFET D'APPARITION AU SCROLL (SCROLL REVEAL)
    // On cible tous les éléments qu'on veut animer
    const observerOptions = {
        root: null,
        rootMargin: '0px',
        threshold: 0.1 // L'animation se déclenche quand 10% de l'objet est visible
    };

    const observer = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                observer.unobserve(entry.target); // On arrête d'observer une fois affiché
            }
        });
    }, observerOptions);

    // On ajoute la classe 'fade-in-section' aux éléments clés
    const sections = document.querySelectorAll('section, .card, h1, .subtitle, .cta-group');
    sections.forEach(section => {
        section.classList.add('fade-in-section');
        observer.observe(section);
    });

    // 2. EFFET SUR LES CARTES (TILT LÉGER 3D)
    const cards = document.querySelectorAll('.card');
    cards.forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            
            // Effet de brillance qui suit la souris
            card.style.setProperty('--x', `${x}px`);
            card.style.setProperty('--y', `${y}px`);
        });
    });
});