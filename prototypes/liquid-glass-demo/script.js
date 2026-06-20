document.addEventListener('DOMContentLoaded', () => {
    const a11ySelect = document.getElementById('a11y-select');
    const body = document.body;
    const expandablePanel = document.querySelector('.expandable');
    const closeBtn = document.getElementById('close-panel');
    const panelContent = document.querySelector('.panel-content');

    // Handle Accessibility Mode Switching
    a11ySelect.addEventListener('change', (e) => {
        body.setAttribute('data-a11y', e.target.value);
    });

    // Handle Elastic Expansion
    expandablePanel.addEventListener('click', (e) => {
        // Only expand if clicked on the panel itself (not inside the expanded content)
        if (!expandablePanel.classList.contains('expanded') && !e.target.closest('button')) {
            expandablePanel.classList.add('expanded');
            panelContent.classList.remove('hidden');
        }
    });

    // Handle Elastic Dissolve/Contract
    closeBtn.addEventListener('click', (e) => {
        e.stopPropagation(); // prevent panel click
        expandablePanel.classList.remove('expanded');
        // Using a timeout to allow the bounce transition to play before hiding content
        setTimeout(() => {
            panelContent.classList.add('hidden');
        }, 600); // matches the transition-duration
    });
});
