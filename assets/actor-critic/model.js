/* A tabular, binary-policy teaching model; not a full PPO implementation. */
(function (root) {
  function compute({ reward = 1, gamma = 1, rate = 0.5, values = [0.2, 0.5, 0.8], probabilities = [0.65, 0.75, 0.2] } = {}) {
    return values.map((value, i) => {
      const probability = probabilities[i];
      const returns = reward * gamma ** (2 - i);
      const advantage = returns - value;
      // Gradient ascent on A * log sigmoid(z), with A held fixed.
      const logit = Math.log(probability / (1 - probability));
      const newLogit = logit + rate * advantage * (1 - probability);
      const newProbability = advantage === 0 ? probability : 1 / (1 + Math.exp(-newLogit));
      // Gradient descent on 1/2 (v - G)^2 for independent scalar v.
      const newValue = value + rate * (returns - value);
      return { value, probability, returns, advantage, newProbability, newValue,
        lossBefore: 0.5 * (value - returns) ** 2,
        lossAfter: 0.5 * (newValue - returns) ** 2 };
    });
  }
  function rounds(firstReward = 1) {
    let values = [0.2, 0.5, 0.8], probabilities = [0.65, 0.75, 0.2];
    return [firstReward, 1 - firstReward, 1].map(reward => {
      const sampled = probabilities.map((p, i) => i === 2 && !reward ? 1 - p : p);
      const data = compute({reward, values, probabilities: sampled});
      const before = probabilities[2];
      values = data.map(r => r.newValue);
      probabilities = data.map((r, i) => i === 2 && !reward ? 1 - r.newProbability : r.newProbability);
      return {reward, data, before, after: probabilities[2]};
    });
  }
  if (typeof module !== 'undefined' && module.exports) module.exports = { compute, rounds };
  else root.ActorCriticModel = { compute, rounds };
})(typeof globalThis !== 'undefined' ? globalThis : this);
