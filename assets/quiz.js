/* ============================================================
   Reusable retrieval-practice quiz component.
   Used by every lesson in ./lessons/.

   Markup contract:

   <div class="quiz" data-quiz>
     <div class="q" data-answer="1">
       <p class="q-stem">Question text</p>
       <div class="opts">
         <button class="opt" data-fb="Shown when chosen.">Option A</button>
         <button class="opt" data-fb="Shown when chosen.">Option B</button>
       </div>
       <p class="fb"></p>
     </div>
   </div>

   data-answer is the ZERO-BASED index of the correct option.
   Every option carries its own data-fb so feedback is immediate
   and specific to the mistake made, not generic.
   ============================================================ */

(function () {
  function initQuiz(quiz) {
    var questions = Array.prototype.slice.call(quiz.querySelectorAll('.q'));
    var answered = 0;
    var correct = 0;

    var score = document.createElement('p');
    score.className = 'score';
    quiz.appendChild(score);

    function render() {
      score.textContent = answered
        ? correct + ' / ' + answered + ' right — ' + (questions.length - answered) + ' to go'
        : '';
    }

    questions.forEach(function (q) {
      var answer = parseInt(q.getAttribute('data-answer'), 10);
      var opts = Array.prototype.slice.call(q.querySelectorAll('.opt'));
      var fb = q.querySelector('.fb');

      opts.forEach(function (opt, i) {
        opt.addEventListener('click', function () {
          if (q.dataset.done) return;
          q.dataset.done = '1';

          var right = i === answer;
          answered++;
          if (right) correct++;

          opts.forEach(function (o, j) {
            o.disabled = true;
            if (j === answer) o.classList.add('correct');
            else if (j === i) o.classList.add('incorrect');
          });

          fb.innerHTML =
            '<strong class="' + (right ? 'ok' : 'no') + '">' +
            (right ? 'Right. ' : 'Not quite. ') + '</strong>' +
            (opt.getAttribute('data-fb') || '');

          render();
        });
      });
    });

    render();
  }

  function boot() {
    Array.prototype.slice
      .call(document.querySelectorAll('[data-quiz]'))
      .forEach(initQuiz);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
