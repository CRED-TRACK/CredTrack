package com.credtrack.backend.service;

import com.credtrack.backend.entity.User;
import com.credtrack.backend.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.Optional;

@Service
public class UserService {

    private static final Logger log = LoggerFactory.getLogger(UserService.class);

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public User createOrUpdateUser(User user) {

        Optional<User> existingUser = userRepository.findById(user.getId());

        if (existingUser.isPresent()) {
            User existing = existingUser.get();
            existing.setLastLogin(LocalDateTime.now());
            existing.setUpdatedAt(LocalDateTime.now());
            User saved = userRepository.save(existing);
            log.info("user_sync event=updated uid={} email={}", saved.getId(), saved.getEmail());
            return saved;
        }

        user.setCreatedAt(LocalDateTime.now());
        user.setLastLogin(LocalDateTime.now());

        User saved = userRepository.save(user);
        log.info("user_sync event=created uid={} email={}", saved.getId(), saved.getEmail());
        return saved;
    }

    public Optional<User> getUserById(String id) {
        return userRepository.findById(id);
    }
}
