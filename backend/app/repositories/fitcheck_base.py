from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class UserRepository(ABC):
    @abstractmethod
    def get(self, user_id: str) -> Any | None:
        pass

    @abstractmethod
    def get_or_create(self, user_id: str, email: str | None = None, display_name: str | None = None) -> Any:
        pass


class CandidateRepository(ABC):
    @abstractmethod
    def create(self, user_id: str, candidate_data: dict[str, Any]) -> Any:
        pass

    @abstractmethod
    def get(self, candidate_id: str, user_id: str) -> Any | None:
        pass

    @abstractmethod
    def list(self, user_id: str) -> list[Any]:
        pass

    @abstractmethod
    def update(self, candidate_id: str, user_id: str, candidate_data: dict[str, Any]) -> Any | None:
        pass

    @abstractmethod
    def delete(self, candidate_id: str, user_id: str) -> bool:
        pass


class JobRepository(ABC):
    @abstractmethod
    def create(self, user_id: str, job_data: dict[str, Any]) -> Any:
        pass

    @abstractmethod
    def get(self, job_id: str, user_id: str) -> Any | None:
        pass

    @abstractmethod
    def list(self, user_id: str) -> list[Any]:
        pass

    @abstractmethod
    def update(self, job_id: str, user_id: str, job_data: dict[str, Any]) -> Any | None:
        pass

    @abstractmethod
    def delete(self, job_id: str, user_id: str) -> bool:
        pass


class InterviewerRepository(ABC):
    @abstractmethod
    def create(self, user_id: str, interviewer_data: dict[str, Any]) -> Any:
        pass

    @abstractmethod
    def get(self, interviewer_id: str, user_id: str | None = None) -> Any | None:
        """Retrieves an interviewer preset or user-owned custom interviewer."""
        pass

    @abstractmethod
    def list_presets(self) -> list[Any]:
        pass

    @abstractmethod
    def list(self, user_id: str) -> list[Any]:
        """Lists both built-in presets and user-owned interviewers."""
        pass

    @abstractmethod
    def update(self, interviewer_id: str, user_id: str, interviewer_data: dict[str, Any]) -> Any | None:
        """Updates a user-owned custom interviewer (presets cannot be edited)."""
        pass

    @abstractmethod
    def delete(self, interviewer_id: str, user_id: str) -> bool:
        pass


class InterviewSessionRepository(ABC):
    @abstractmethod
    def create(self, user_id: str, session_data: dict[str, Any]) -> Any:
        pass

    @abstractmethod
    def get(self, session_id: str, user_id: str) -> Any | None:
        pass

    @abstractmethod
    def list(self, user_id: str) -> list[Any]:
        pass

    @abstractmethod
    def update_transcript(self, session_id: str, user_id: str, transcript: list[dict[str, Any]]) -> bool:
        pass

    @abstractmethod
    def end_session(self, session_id: str, user_id: str, transcript: list[dict[str, Any]] | None = None) -> Any | None:
        pass


class EvaluationRepository(ABC):
    @abstractmethod
    def create(self, user_id: str, evaluation_data: dict[str, Any]) -> Any:
        pass

    @abstractmethod
    def get_by_session(self, session_id: str, user_id: str) -> Any | None:
        pass

    @abstractmethod
    def list(self, user_id: str) -> list[Any]:
        pass
